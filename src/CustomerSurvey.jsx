import ThaiProvinceInput from "./ThaiProvinceInput";
import GoogleMapPicker from "./GoogleMapPicker";
import React, { useState } from "react";
import { configured, rpc } from "./backend";
export const surveyOptions = {
  service: [
    "ติดตั้งโซลาร์เซลล์ Sigenergy (บ้าน/ธุรกิจ)",
    "ซื้อสินค้า (EPC / Installer)",
    "ขอคำปรึกษา",
  ],
  property: ["บ้านพักอาศัย", "สำนักงาน/ ออฟฟิศ", "โรงงาน"],
  ev: ["มี", "ไม่มี"],
  usage: ["ใช้ช่วงกลางวันเป็นหลัก", "ใช้ช่วงกลางคืนเป็นหลัก", "ตลอดเวลา"],
  system: [
    "โซลาร์เซลล์ Sigenergy อย่างเดียว",
    "โซลาร์ + แบตเตอรี่ (Sigenergy)",
    "EV Charger",
  ],
  battery: ["ต้องการ", "ไม่ต้องการ", "ขอคำแนะนำ"],
  timeline: ["ด่วน (ภายใน 1 เดือน)", "1 - 3 เดือน", "กำลังศึกษา"],
  contact: ["ติดต่อด่วน", "ในเวลาทำการ", "ส่งใบเสนอราคา", "นัดสำรวจหน้างาน"],
};
export default function CustomerSurvey({ compact = false }) {
  const [step, setStep] = useState(0),
    [v, setV] = useState({}),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [done, setDone] = useState("");
  const set = (k, x) => setV((p) => ({ ...p, [k]: x }));
  const choice = (key, title) => (
    <label>
      {title}
      <select
        required
        value={v[key] || ""}
        onChange={(e) => set(key, e.target.value)}
      >
        <option value="" disabled>
          กรุณาเลือก
        </option>
        {surveyOptions[key].map((x) => (
          <option key={x}>{x}</option>
        ))}
      </select>
    </label>
  );
  const input = (
    key,
    title,
    type = "text",
    required = true,
    maxLength = 200,
  ) => (
    <label>
      {title}
      <input
        type={type}
        name={key}
        required={required}
        maxLength={maxLength}
        value={v[key] || ""}
        onChange={(e) => set(key, e.target.value)}
        {...(type === "number" ? { min: 1, max: 100000000, step: "0.01" } : {})}
      />
    </label>
  );
  function showInvalidField(event) {
    event.preventDefault();
    const field = event.target;
    const firstInvalid = event.currentTarget.querySelector(":invalid:not(fieldset)");
    if (field !== firstInvalid) return;
    const { type } = field;
    const label = (field.getAttribute("aria-label") || field.labels?.[0]?.textContent)
      ?.split("กรุณาเลือก")[0].trim().replace(/^\d+\.\s*|\s*\*$/g, "");
    const messages = {
      email: "กรุณากรอกอีเมลให้ถูกต้อง",
      number: "กรุณากรอกค่าไฟเป็นตัวเลขระหว่าง 1 ถึง 100,000,000 บาท",
      checkbox: "กรุณายืนยันความยินยอมก่อนส่งข้อมูล",
    };
    setError(messages[type] || (label ? "กรุณาระบุ " + label : "กรุณากรอกข้อมูลให้ครบ"));
    field.focus();
  }
  async function next(e) {
    e.preventDefault();
    setError("");
    if (step === 0 && !v.name?.trim()) {
      setError("กรุณากรอกชื่อ-นามสกุล");
      return;
    }
    if (step === 0 && !v.phone?.trim() && !v.line?.trim()) {
      setError("กรุณากรอกเบอร์โทรหรือ Line ID อย่างน้อยหนึ่งช่อง");
      return;
    }
    if (step === 0) {
      const phone = (v.phone || "")
        .replace(/[๐-๙]/g, (digit) => String(digit.charCodeAt(0) - 0x0e50))
        .replace(/[\s().-]/g, "");
      if (v.phone?.trim() && !/^\+?[0-9]{9,15}$/.test(phone)) {
        setError("กรุณากรอกเบอร์โทร 9–15 หลัก เช่น 081 234 5678 หรือเว้นช่องนี้แล้วกรอก Line ID");
        e.currentTarget.elements.namedItem("phone")?.focus();
        return;
      }
      set("phone", phone);
      setStep(1);
      return;
    }
    if (!configured) {
      setError("ยังไม่พร้อมรับข้อมูล กรุณาติดต่อทีมงาน");
      return;
    }
    setBusy(true);
    try {
      const p = new URLSearchParams(location.search);
      const medium = p.get("utm_medium")?.trim().slice(0, 150);
      setDone(
        await rpc("tw_submit_customer_survey", {
          p_data: medium ? { ...v, utm_medium: medium } : v,
          p_source: p.get("utm_source") || "หน้าแบบสอบถาม",
          p_campaign: p.get("utm_campaign") || "",
          p_consent: true,
        }),
      );
    } catch (e) {
      setError(e.message || "ส่งข้อมูลไม่สำเร็จ");
    } finally {
      setBusy(false);
    }
  }
  if (done)
    return (
      <div className="success" role="status">
        <div>✓</div>
        <h2>ได้รับข้อมูลของคุณแล้ว</h2>
        <p>ทีม Terawatt จะติดต่อกลับตามความต้องการที่แจ้งไว้</p>
        <small>หมายเลขอ้างอิง {done}</small>
      </div>
    );
  return (
    <>
      <div className="question-top">
        <span>{compact ? "แบบประเมินเบื้องต้น" : "ประเมินโซลาร์ Sigenergy"}</span>
        <small>ขั้นตอน {step + 1} / 2</small>
      </div>
      <div className="progress">
        <div style={{ width: ((step + 1) / 2) * 100 + "%" }} />
      </div>
      <form key={step} onSubmit={next} onInvalidCapture={showInvalidField}>
        <fieldset disabled={busy} className="lead-fieldset">
          <h2>
            {
              [
                compact ? "ติดต่อคุณทางไหนได้บ้าง?" : "บริการและช่องทางติดต่อ",
                "สถานที่และการใช้พลังงาน",
              ][step]
            }
          </h2>
          {step === 0 && (
            <>
              {input("name", compact ? "ชื่อ-นามสกุล *" : "1. ชื่อ-นามสกุล *", "text", true, 150)}
              {input(
                "phone",
                compact ? "เบอร์โทร" : "2. เบอร์โทร (หรือกรอก Line ID ด้านล่าง)",
                "tel",
                false,
                32,
              )}
              {input("line", "Line ID", "text", false, 100)}
              <p className="field-help">
                กรอกเบอร์โทรหรือ Line ID อย่างน้อยหนึ่งช่อง
              </p>
              {input("email", "อีเมล (ไม่บังคับ)", "email", false, 254)}
            </>
          )}
          {step === 1 && (
            <>
              <GoogleMapPicker value={v.gps} onChange={(gps)=>set("gps",gps)}/>
              <ThaiProvinceInput value={v.province} onChange={(province)=>set("province",province)}/>
              {choice("property", "5. ประเภทสถานที่ *")}
              {input("billAmount", "6. ค่าไฟต่อเดือน (บาท) *", "number")}
              <p className="field-help">
                {v.property === "บ้านพักอาศัย"
                  ? "กรอกค่าไฟเฉลี่ยต่อเดือน"
                  : "สำนักงานและโรงงานกรอกค่าไฟจริงต่อเดือน เพื่อประเมินขนาดระบบ"}
              </p>
              {choice("ev", "7. ท่านมีรถยนต์ไฟฟ้า (EV) หรือไม่ *")}
              {choice("usage", "8. ความต้องการในการใช้โซลาร์เซลล์ *")}
              {choice("battery", "9. ต้องการแบตเตอรี่หรือไม่ *")}
              <label className="consent">
                <input type="checkbox" required />
                ยินยอมให้ Terawatt เก็บข้อมูลและคำตอบ
                เพื่อให้ทีมงานและพาร์ทเนอร์ EPC ติดต่อให้คำปรึกษา เสนอราคา
                และบริการตามที่ร้องขอ
              </label>
            </>
          )}
        </fieldset>
        {error && (
          <p role="alert" className="form-error">
            {error}
          </p>
        )}
        <div className="question-controls">
          {(!compact || step > 0) && <button
            type="button"
            className="btn"
            disabled={step === 0 || busy}
            onClick={() => {
              setError("");
              setStep(step - 1);
            }}
          >
            ย้อนกลับ
          </button>}
          <button className="btn primary" disabled={busy}>
            {busy
              ? "กำลังส่งข้อมูล…"
              : step === 1
                ? "ส่งข้อมูลให้ Terawatt"
                : "ถัดไป →"}
          </button>
        </div>
      </form>
    </>
  );
}
