import React, { useState } from "react";
import { supabase } from "./backend";
export default function AdminPassword({ email, onClose }) {
  const [busy, setBusy] = useState(false),
    [message, setMessage] = useState("");
  async function save(e) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const password = f.get("password");
    if (password !== f.get("confirm")) {
      setMessage("รหัสผ่านใหม่ไม่ตรงกัน");
      return;
    }
    setBusy(true);
    setMessage("");
    try {
      const verify = await supabase.auth.signInWithPassword({
        email,
        password: f.get("current"),
      });
      if (verify.error) throw Error("รหัสผ่านปัจจุบันไม่ถูกต้อง");
      const r = await supabase.auth.updateUser({ password });
      if (r.error) throw r.error;
      setMessage("เปลี่ยนรหัสผ่านสำเร็จแล้ว");
      e.target.reset();
    } catch (e) {
      setMessage(e.message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="overlay">
      <section
        className="modal"
        role="dialog"
        aria-modal="true"
        aria-label="เปลี่ยนรหัสผ่าน Admin"
      >
        <h2>เปลี่ยนรหัสผ่าน Admin</h2>
        <form onSubmit={save}>
          <label>
            รหัสผ่านปัจจุบัน
            <input
              type="password"
              name="current"
              autoComplete="current-password"
              required
            />
          </label>
          <label>
            รหัสผ่านใหม่ (12–128 ตัวอักษร)
            <input
              type="password"
              name="password"
              minLength={12}
              maxLength={128}
              autoComplete="new-password"
              required
            />
          </label>
          <label>
            ยืนยันรหัสผ่านใหม่
            <input
              type="password"
              name="confirm"
              minLength={12}
              maxLength={128}
              autoComplete="new-password"
              required
            />
          </label>
          {message && <p role="status">{message}</p>}
          <div className="question-controls">
            <button
              className="btn"
              type="button"
              disabled={busy}
              onClick={onClose}
            >
              ปิด
            </button>
            <button className="btn primary" disabled={busy}>
              {busy ? "กำลังบันทึก…" : "เปลี่ยนรหัสผ่าน"}
            </button>
          </div>
        </form>
      </section>
    </div>
  );
}
