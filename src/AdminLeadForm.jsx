import React, { useState } from "react";
import { X, UserPlus } from "lucide-react";
import { rpc } from "./backend";
import { leadFields, dateFields } from "./leadFields";
import { leadQuestions } from "./leadQuestions";
export default function AdminLeadForm({ onClose, onSaved }) {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function save(e) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    const f = new FormData(e.currentTarget);
    try {
      const id = await rpc("tw_admin_create_lead", {
        p_details: Object.fromEntries(
          leadFields.map((k) => [k, f.get(k) || ""]),
        ),
        p_lead: {
          name: f.get("name").trim(),
          phone: f.get("phone").trim(),
          email: f.get("email").trim(),
          province: f.get("province").trim(),
          answers: Object.fromEntries(
            leadQuestions.map((q) => [q.key, f.get(q.key)]),
          ),
          source: "Admin / " + f.get("source"),
          campaign: f.get("campaign").trim(),
        },
      });
      await onSaved(id);
    } catch (e) {
      setError(e.message || "บันทึก Lead ไม่สำเร็จ กรุณาลองใหม่");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="overlay" onClick={() => !busy && onClose()}>
      <section
        className="modal admin-lead-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="add-lead-title"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          className="close-button"
          type="button"
          disabled={busy}
          aria-label="ปิดฟอร์มเพิ่ม Lead"
          onClick={onClose}
        >
          <X size={20} />
        </button>
        <div className="eyebrow">NEW CUSTOMER LEAD</div>
        <h2 id="add-lead-title">เพิ่ม Lead ลูกค้า</h2>
        <p>บันทึกข้อมูลลูกค้าเข้าระบบ แล้วเลือกมอบหมายให้ EPC ภายหลัง</p>
        <form onSubmit={save}>
          <fieldset disabled={busy} className="lead-fieldset">
            <label>
              ชื่อผู้ติดต่อ / บริษัท *
              <input
                name="name"
                required
                maxLength={150}
                autoFocus
                autoComplete="name"
              />
            </label>
            <div className="form-grid">
              <label>
                เบอร์โทรศัพท์ *
                <input
                  name="phone"
                  type="tel"
                  required
                  minLength={9}
                  maxLength={16}
                  autoComplete="tel"
                />
              </label>
              <label>
                อีเมลลูกค้า *
                <input
                  name="email"
                  type="email"
                  required
                  maxLength={254}
                  autoComplete="email"
                />
              </label>
            </div>
            <label>
              จังหวัดที่ติดตั้ง *
              <input name="province" required maxLength={100} />
            </label>
            <div className="form-grid">
              {leadQuestions.map((q) => (
                <label key={q.key}>
                  {q.title} *
                  <select name={q.key} required defaultValue="">
                    <option value="" disabled>
                      เลือกคำตอบ
                    </option>
                    {q.options.map((o) => (
                      <option key={o} value={o}>
                        {o}
                      </option>
                    ))}
                  </select>
                </label>
              ))}
            </div>
            <div className="form-grid">
              <label>
                ช่องทางที่ได้รับ Lead
                <select name="source" defaultValue="กรอกด้วยตนเอง">
                  {[
                    "กรอกด้วยตนเอง",
                    "Facebook",
                    "Instagram",
                    "โทรศัพท์",
                    "งานอีเวนต์",
                    "อื่น ๆ",
                  ].map((o) => (
                    <option key={o}>{o}</option>
                  ))}
                </select>
              </label>
              <label>
                ชื่อแคมเปญ / อ้างอิง
                <input
                  name="campaign"
                  maxLength={200}
                  placeholder="ไม่บังคับ"
                />
              </label>
            </div>
            <h3>รายละเอียดโครงการและข้อมูลติดตาม</h3>
            <p>
              ข้อมูลพาร์ทเนอร์และวันเวลาเดิมเป็นข้อมูลอ้างอิง
              การมอบหมายจริงให้ใช้ปุ่มส่งให้ EPC หลังบันทึก
            </p>
            <div className="form-grid">
              {leadFields.map((k) => (
                <label key={k}>
                  {k}
                  <input
                    name={k}
                    type={
                      dateFields.includes(k)
                        ? "datetime-local"
                        : k === "Partner Email"
                          ? "email"
                          : "text"
                    }
                    maxLength={k === "Requirement" ? 2000 : 254}
                  />
                </label>
              ))}
            </div>
            <label className="consent">
              <input type="checkbox" required />
              ยืนยันว่าได้รับความยินยอมจากลูกค้าให้ Terawatt
              เก็บข้อมูลและส่งต่อให้พาร์ทเนอร์ EPC เพื่อติดต่อเสนอการติดตั้งแล้ว
            </label>
          </fieldset>
          {error && (
            <div className="form-error" role="alert">
              {error}
            </div>
          )}
          <div className="question-controls">
            <button
              className="btn"
              type="button"
              disabled={busy}
              onClick={onClose}
            >
              ยกเลิก
            </button>
            <button className="btn primary" disabled={busy}>
              <UserPlus size={16} />
              {busy ? "กำลังบันทึก…" : "บันทึก Lead"}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
