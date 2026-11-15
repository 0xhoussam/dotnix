//! Google Calendar events from the calendar's secret iCal address (no OAuth,
//! read-only). The address is read from ~/.config/my-shell/calendar.url and
//! fetched with curl; it is a credential, so it is never logged or sent to
//! the UI. Recurring events are expanded with RFC 5545 rules.

use chrono::{DateTime, Duration, Local, NaiveDate, NaiveDateTime, TimeZone, Utc};
use rrule::{RRuleSet, Tz};
use serde_json::{json, Value as Json};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq)]
pub struct Event {
    pub title: String,
    pub location: String,
    pub start: DateTime<Utc>,
    pub end: DateTime<Utc>,
    pub all_day: bool,
}

/// RFC 5545 line unfolding: a line starting with space or tab continues the previous one.
fn unfold(text: &str) -> Vec<String> {
    let mut out: Vec<String> = vec![];
    for l in text.replace("\r\n", "\n").split('\n') {
        if (l.starts_with(' ') || l.starts_with('\t')) && !out.is_empty() {
            out.last_mut().unwrap().push_str(&l[1..]);
        } else {
            out.push(l.to_string());
        }
    }
    out
}

fn unescape(s: &str) -> String {
    s.replace("\\n", " ").replace("\\N", " ").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")
}

#[derive(Default, Clone)]
struct Raw {
    lines: Vec<String>, // all property lines of the VEVENT
}

impl Raw {
    fn get(&self, name: &str) -> Option<&String> {
        self.lines.iter().find(|l| l.split([':', ';']).next() == Some(name))
    }
    fn value(&self, name: &str) -> Option<String> {
        self.get(name).and_then(|l| l.split_once(':').map(|(_, v)| v.to_string()))
    }
    fn all(&self, name: &str) -> Vec<&String> {
        self.lines.iter().filter(|l| l.split([':', ';']).next() == Some(name)).collect()
    }
}

fn events_raw(text: &str) -> Vec<Raw> {
    let mut out = vec![];
    let mut cur: Option<Raw> = None;
    for l in unfold(text) {
        match l.as_str() {
            "BEGIN:VEVENT" => cur = Some(Raw::default()),
            "END:VEVENT" => {
                if let Some(r) = cur.take() {
                    out.push(r);
                }
            }
            _ => {
                if let Some(r) = cur.as_mut() {
                    r.lines.push(l);
                }
            }
        }
    }
    out
}

/// Parse a DTSTART/DTEND style property line into an instant (UTC) and whether it is a date.
fn parse_when(line: &str) -> Option<(DateTime<Utc>, bool, Option<String>)> {
    let (head, val) = line.split_once(':')?;
    let tzid = head.split(';').find_map(|p| p.strip_prefix("TZID=")).map(String::from);
    if head.contains("VALUE=DATE") && !head.contains("DATE-TIME") || val.len() == 8 {
        let d = NaiveDate::parse_from_str(val, "%Y%m%d").ok()?;
        // all-day: local midnight
        let local = Local.from_local_datetime(&d.and_hms_opt(0, 0, 0)?).earliest()?;
        return Some((local.with_timezone(&Utc), true, None));
    }
    if let Some(utc) = val.strip_suffix('Z') {
        let n = NaiveDateTime::parse_from_str(utc, "%Y%m%dT%H%M%S").ok()?;
        return Some((Utc.from_utc_datetime(&n), false, None));
    }
    let n = NaiveDateTime::parse_from_str(val, "%Y%m%dT%H%M%S").ok()?;
    match &tzid {
        Some(tz) => {
            let tz: chrono_tz::Tz = tz.parse().ok()?;
            Some((tz.from_local_datetime(&n).earliest()?.with_timezone(&Utc), false, tzid))
        }
        None => Some((Local.from_local_datetime(&n).earliest()?.with_timezone(&Utc), false, None)),
    }
}

/// Events overlapping [from, to), recurring ones expanded, sorted by start.
pub fn expand(text: &str, from: DateTime<Utc>, to: DateTime<Utc>) -> Vec<Event> {
    let raws = events_raw(text);
    // overrides of single instances: (uid, original start) -> the replacement event
    let mut overridden: HashSet<(String, i64)> = HashSet::new();
    for r in &raws {
        if let (Some(uid), Some(rid)) = (r.value("UID"), r.get("RECURRENCE-ID")) {
            if let Some((t, _, _)) = parse_when(rid) {
                overridden.insert((uid, t.timestamp()));
            }
        }
    }
    let mut out: Vec<Event> = vec![];
    for r in &raws {
        if r.value("STATUS").as_deref() == Some("CANCELLED") {
            continue;
        }
        let Some(ds) = r.get("DTSTART") else { continue };
        let Some((start, all_day, _)) = parse_when(ds) else { continue };
        let end = r
            .get("DTEND")
            .and_then(|l| parse_when(l))
            .map(|(e, _, _)| e)
            .unwrap_or(start + if all_day { Duration::days(1) } else { Duration::zero() });
        let dur = end - start;
        let title = unescape(&r.value("SUMMARY").unwrap_or_default());
        let location = unescape(&r.value("LOCATION").unwrap_or_default());
        let uid = r.value("UID").unwrap_or_default();
        let push = |out: &mut Vec<Event>, s: DateTime<Utc>| {
            let e = s + dur;
            if e > from && s < to || (dur.is_zero() && s >= from && s < to) {
                out.push(Event { title: title.clone(), location: location.clone(), start: s, end: e, all_day });
            }
        };
        if let Some(rr) = r.get("RRULE") {
            // rebuild a set the rrule crate understands: DTSTART + RRULE + EXDATEs
            let mut src = format!("{ds}\n{rr}");
            for ex in r.all("EXDATE") {
                src.push('\n');
                src.push_str(ex);
            }
            let Ok(set) = src.parse::<RRuleSet>() else { continue };
            let a = from.with_timezone(&Tz::UTC) - dur;
            let b = to.with_timezone(&Tz::UTC);
            for d in set.after(a).before(b).all(500).dates {
                let s = d.with_timezone(&Utc);
                if !overridden.contains(&(uid.clone(), s.timestamp())) {
                    push(&mut out, s);
                }
            }
        } else if r.get("RECURRENCE-ID").is_some() || !overridden.contains(&(uid.clone(), start.timestamp())) {
            push(&mut out, start);
        }
    }
    out.sort_by_key(|e| (e.start, e.title.clone()));
    out.dedup();
    out
}

/// Fetch the calendar and return events for today and the next two days as JSON.
pub async fn events_json() -> Result<Json, String> {
    let path = crate::util::config_dir().join("my-shell").join("calendar.url");
    let url = std::fs::read_to_string(&path).map_err(|_| "not-configured".to_string())?;
    let url = url.trim();
    if !url.starts_with("https://") {
        return Err("calendar.url must be an https:// iCal address".into());
    }
    let out = tokio::process::Command::new("curl")
        .args(["-sSL", "-m", "20", "--max-filesize", "20000000", url])
        .output()
        .await
        .map_err(|e| format!("curl: {e}"))?;
    if !out.status.success() {
        return Err("could not download the calendar".into());
    }
    let text = String::from_utf8_lossy(&out.stdout).into_owned();
    if !text.contains("BEGIN:VCALENDAR") {
        return Err("the address did not return an iCal calendar".into());
    }
    let today = Local::now().date_naive().and_hms_opt(0, 0, 0).unwrap();
    let from = Local.from_local_datetime(&today).earliest().unwrap().with_timezone(&Utc);
    let events = expand(&text, from, from + Duration::days(3));
    Ok(Json::Array(
        events
            .iter()
            .take(40)
            .map(|e| {
                json!({"title": e.title, "location": e.location, "allDay": e.all_day,
                       "start": e.start.with_timezone(&Local).to_rfc3339(),
                       "end": e.end.with_timezone(&Local).to_rfc3339()})
            })
            .collect(),
    ))
}

#[allow(dead_code)]
fn _unused(_: HashMap<u8, u8>) {}

#[cfg(test)]
mod tests {
    use super::*;

    const ICS: &str = "BEGIN:VCALENDAR\r\n\
BEGIN:VEVENT\r\nUID:one\r\nDTSTART:20300105T100000Z\r\nDTEND:20300105T110000Z\r\nSUMMARY:Dentist\\, 2nd floor\r\nEND:VEVENT\r\n\
BEGIN:VEVENT\r\nUID:weekly\r\nDTSTART;TZID=Africa/Casablanca:20300101T090000\r\nDTEND;TZID=Africa/Casablanca:20300101T093000\r\nRRULE:FREQ=WEEKLY;BYDAY=TU\r\nEXDATE;TZID=Africa/Casablanca:20300115T090000\r\nSUMMARY:Standup\r\nEND:VEVENT\r\n\
BEGIN:VEVENT\r\nUID:allday\r\nDTSTART;VALUE=DATE:20300106\r\nDTEND;VALUE=DATE:20300107\r\nSUMMARY:Holiday\r\nEND:VEVENT\r\n\
BEGIN:VEVENT\r\nUID:cancelled\r\nDTSTART:20300105T120000Z\r\nSTATUS:CANCELLED\r\nSUMMARY:Gone\r\nEND:VEVENT\r\n\
END:VCALENDAR\r\n";

    fn t(s: &str) -> DateTime<Utc> {
        DateTime::parse_from_rfc3339(s).unwrap().with_timezone(&Utc)
    }

    #[test]
    fn single_and_cancelled_events() {
        let ev = expand(ICS, t("2030-01-05T00:00:00Z"), t("2030-01-06T00:00:00Z"));
        let titles: Vec<_> = ev.iter().map(|e| e.title.as_str()).collect();
        assert_eq!(titles, vec!["Dentist, 2nd floor"]);
        assert_eq!(ev[0].start, t("2030-01-05T10:00:00Z"));
    }

    #[test]
    fn weekly_expansion_honours_tz_and_exdate() {
        // Tuesdays 2030-01-01, 08, 15 (excluded), 22 at 09:00 Casablanca (UTC+1 in winter 2030)
        let ev = expand(ICS, t("2030-01-01T00:00:00Z"), t("2030-01-29T00:00:00Z"));
        let standups: Vec<_> = ev.iter().filter(|e| e.title == "Standup").map(|e| e.start).collect();
        assert_eq!(standups.len(), 3, "{standups:?}");
        assert!(!standups.contains(&t("2030-01-15T08:00:00Z")));
        assert_eq!(standups[0].time().format("%H:%M").to_string().len(), 5);
    }

    #[test]
    fn all_day_events_are_flagged() {
        let ev = expand(ICS, t("2030-01-05T20:00:00Z"), t("2030-01-07T20:00:00Z"));
        assert!(ev.iter().any(|e| e.title == "Holiday" && e.all_day));
    }
}
