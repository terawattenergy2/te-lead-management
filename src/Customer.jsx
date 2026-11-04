import CustomerSurvey from "./CustomerSurvey";
import {
  ArrowUpRight,
  ArrowRight,
  Sun,
  ShieldCheck,
  BatteryCharging,
  House,
  Factory,
  Building2,
  Zap,
  Check,
} from "lucide-react";
import React, { useState } from "react";

export default function Customer() {
  const [motion, setMotion] = useState(
    () => !window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  return (
    <div className={"solar-site" + (motion ? "" : " motion-paused")}>
      <header className="solar-nav">
        <a className="solar-wordmark" href="#customer">
          <span className="te-logo">
            <img src="/assets/terawatt-logo.png" alt="Terawatt Energy" />
          </span>
        </a>
        <nav aria-label="เมนูเว็บไซต์">
          <button
            onClick={() =>
              document
                .getElementById("solar-solutions")
                .scrollIntoView({ behavior: "smooth" })
            }
          >
            โซลูชันพลังงาน
          </button>
          <button
            onClick={() =>
              document
                .getElementById("solar-process")
                .scrollIntoView({ behavior: "smooth" })
            }
          >
            เริ่มต้นอย่างไร
          </button>
          <a href="#epc">สำหรับ EPC</a>
        </nav>
        <button
          className="solar-btn"
          onClick={() =>
            document
              .getElementById("solar-assessment")
              .scrollIntoView({ behavior: "smooth" })
          }
        >
          ปรึกษาเรื่องโซลาร์ <ArrowUpRight size={16} />
        </button>
      </header>
      <section className="solar-hero" aria-labelledby="solar-headline">
        <div className="solar-hero-art" aria-hidden="true" />
        <div className="solar-hero-haze" aria-hidden="true" />
        <svg
          className="energy-motion"
          viewBox="0 0 1440 800"
          preserveAspectRatio="xMidYMid slice"
          aria-hidden="true"
        >
          <defs>
            <linearGradient id="energy-line">
              <stop stopColor="#79cbef" stopOpacity="0" />
              <stop offset=".5" stopColor="#d6f7ff" />
              <stop offset="1" stopColor="#5a99da" stopOpacity="0" />
            </linearGradient>
          </defs>
          <path
            className="energy-path energy-path-1"
            d="M850 290 Q1160 175 1190 420 T1040 665"
          />
          <path
            className="energy-path energy-path-2"
            d="M800 300 Q1000 245 1110 395 T1270 600"
          />
          <circle className="sun-ring" cx="1195" cy="165" r="86" />
          <circle className="sun-ring ring-two" cx="1195" cy="165" r="110" />
        </svg>
        <div className="solar-hero-copy">
          <div className="solar-overline">
            <i /> CLEAN ENERGY. PERSONALIZED.
          </div>
          <h1 id="solar-headline">
            พลังงานที่ดี
            <br />
            เริ่มต้นที่<span>คุณ.</span>
          </h1>
          <p className="solar-english">
            A brighter home.
            <br />
            <em>A better tomorrow.</em>
          </p>
          <p className="solar-description">
            เปลี่ยนแสงอาทิตย์ให้เป็นพลังงานของคุณ
            <br />
            เชื่อมต่อผู้ติดตั้งโซลาร์ที่เหมาะกับบ้านและธุรกิจ
            <br />
            เริ่มจากความต้องการของคุณ ในไม่กี่คำถาม
          </p>
          <button
            className="solar-btn"
            onClick={() =>
              document
                .getElementById("solar-assessment")
                .scrollIntoView({ behavior: "smooth" })
            }
          >
            ค้นหาโซลูชันของคุณ <ArrowRight size={17} />
          </button>
          <div className="solar-caption">
            <Sun size={14} /> SMARTER ENERGY, MADE SIMPLE.
          </div>
        </div>
        <div
          className="solar-glass-widget"
          aria-label="ภาพจำลองระบบพลังงานโซลาร์"
        >
          <div className="widget-top">
            <span>
              <i /> SOLAR INTELLIGENCE
            </span>
            <Sun size={19} />
          </div>
          <p className="widget-title">
            พลังงานสะอาด
            <br />
            <strong>ที่เชื่อมถึงกัน</strong>
          </p>
          <div className="energy-progress">
            <span />
          </div>
          <div className="widget-item">
            <span className="widget-icon">
              <Sun size={23} />
            </span>
            <div>
              <small>ROOFTOP SOLAR</small>
              <strong>เริ่มต้นจากแสงอาทิตย์</strong>
              <p>เปลี่ยนแสงให้เป็นพลังงาน</p>
            </div>
            <Zap className="widget-zap" size={17} />
          </div>
          <div className="widget-item">
            <span className="widget-icon">
              <BatteryCharging size={23} />
            </span>
            <div>
              <small>HOME ENERGY</small>
              <strong>เชื่อมต่อทุกช่วงเวลา</strong>
              <p>โซลาร์ · แบตเตอรี่ · การใช้ไฟ</p>
            </div>
          </div>
          <div className="widget-foot">
            <Check size={16} />
            <span>ภาพจำลองการไหลของพลังงาน</span>
          </div>
        </div>
        <button
          className="motion-toggle"
          aria-pressed={!motion}
          onClick={() => setMotion(!motion)}
        >
          {motion ? "หยุดภาพเคลื่อนไหว" : "เล่นภาพเคลื่อนไหว"}
        </button>
        <div className="solar-hero-index">
          <span>01 / THE FUTURE IS SOLAR</span>
          <span>TERAWATT ENERGY SYSTEMS</span>
        </div>
      </section>
      <section className="solar-discover-strip">
        <div className="strip-image" aria-hidden="true" />
        <div className="strip-title">
          <span className="solar-overline">DESIGNED AROUND YOU</span>
          <h2>โซลาร์ที่เข้าใจทุกความต้องการ</h2>
          <button
            onClick={() =>
              document
                .getElementById("solar-solutions")
                .scrollIntoView({ behavior: "smooth" })
            }
          >
            สำรวจโซลูชัน <ArrowRight size={14} />
          </button>
        </div>
        <div className="strip-benefit">
          <ShieldCheck size={28} />
          <span>
            พาร์ทเนอร์ EPC
            <br />
            สำหรับโครงการของคุณ
          </span>
        </div>
        <div className="strip-benefit">
          <House size={28} />
          <span>
            บ้านและธุรกิจ
            <br />
            เริ่มต้นได้ในที่เดียว
          </span>
        </div>
        <button
          className="solar-btn bright"
          onClick={() =>
            document
              .getElementById("solar-assessment")
              .scrollIntoView({ behavior: "smooth" })
          }
        >
          เริ่มประเมินเลย <ArrowUpRight size={21} />
        </button>
      </section>
      <section className="solar-solutions" id="solar-solutions">
        <div className="section-intro">
          <div>
            <div className="solar-overline">ONE SUN. MANY POSSIBILITIES.</div>
            <h2>
              พลังงานของทุกวัน
              <br />
              <span>ออกแบบให้เป็นของคุณ</span>
            </h2>
          </div>
          <p>
            ไม่ว่าจะเป็นบ้าน อาคาร หรือโรงงาน
            <br />
            Terawatt ช่วยส่งต่อความต้องการของคุณ
            <br />
            ให้พาร์ทเนอร์ผู้ติดตั้งที่เหมาะสม
          </p>
        </div>
        <div className="solution-grid">
          {[
            {
              Icon: House,
              title: "บ้านพักอาศัย",
              sub: "A BRIGHTER HOME",
              description:
                "เริ่มวางแผนระบบโซลาร์สำหรับบ้าน ให้สอดคล้องกับพื้นที่และพฤติกรรมการใช้ไฟ",
              label: "สำหรับบ้าน",
            },
            {
              Icon: Building2,
              title: "อาคารพาณิชย์",
              sub: "ENERGY FOR BUSINESS",
              description:
                "บอกความต้องการด้านพลังงานของอาคาร เพื่อให้ผู้ติดตั้งประเมินและเสนอแนวทาง",
              label: "สำหรับธุรกิจ",
            },
            {
              Icon: Factory,
              title: "โรงงานและอุตสาหกรรม",
              sub: "POWER YOUR NEXT CHAPTER",
              description:
                "เชื่อมต่อพาร์ทเนอร์ EPC เพื่อวางแผนระบบที่เหมาะกับขนาดและรูปแบบการใช้ไฟ",
              label: "สำหรับอุตสาหกรรม",
            },
          ].map(({ Icon, title, sub, description, label }, i) => (
            <article className={"solution-card solution-" + i} key={title}>
              <div className="solution-visual">
                <Icon size={72} strokeWidth={0.8} />
                <span className="solution-orbit" />
                <span className="solution-orbit second" />
                <Sun className="solution-sun" size={26} />
              </div>
              <small>{sub}</small>
              <h3>{title}</h3>
              <p>{description}</p>
              <button
                onClick={() => {
                  setAnswers((prev) => ({
                    ...prev,
                    property:
                      title === "โรงงานและอุตสาหกรรม"
                        ? "โรงงาน / อุตสาหกรรม"
                        : title,
                  }));
                  document
                    .getElementById("solar-assessment")
                    .scrollIntoView({ behavior: "smooth" });
                }}
              >
                {label} <ArrowUpRight size={17} />
              </button>
            </article>
          ))}
        </div>
      </section>
      <section className="solar-process" id="solar-process">
        <div className="solar-overline">YOUR JOURNEY TO SOLAR</div>
        <h2>จากความสนใจ สู่การเริ่มต้นที่ชัดเจน</h2>
        <div className="process-grid">
          {[
            [
              "01",
              "บอกความต้องการ",
              "แจ้งบริการที่สนใจ สถานที่ ค่าไฟ และระบบที่ต้องการ",
            ],
            [
              "02",
              "ให้เราเชื่อมต่อ",
              "ทีม Terawatt ประสานพาร์ทเนอร์ EPC ที่เหมาะกับโครงการ",
            ],
            [
              "03",
              "รับคำแนะนำ",
              "ผู้ติดตั้งติดต่อกลับเพื่อประเมินและเสนอรายละเอียด",
            ],
          ].map(([n, title, text]) => (
            <div key={n}>
              <span>{n}</span>
              <h3>{title}</h3>
              <p>{text}</p>
            </div>
          ))}
        </div>
      </section>
      <section className="solar-assessment" id="solar-assessment">
        <div className="assessment-intro">
          <div className="solar-overline">LET'S FIND YOUR SOLAR FIT</div>
          <h2>
            เริ่มต้นอนาคต
            <br />
            พลังงานของคุณ<span>.</span>
          </h2>
          <p>
            ตอบคำถามเกี่ยวกับความต้องการของคุณ
            <br />
            เพื่อให้เราเข้าใจความต้องการของคุณมากขึ้น
          </p>
          <div className="assessment-points">
            <span>
              <Check size={16} /> สำหรับบ้าน อาคาร และโรงงาน
            </span>
            <span>
              <Check size={16} /> ส่งต่อให้พาร์ทเนอร์ตามความยินยอม
            </span>
            <span>
              <ShieldCheck size={16} /> ข้อมูลติดต่อเปิดเมื่อ EPC ยืนยันรับ Lead
            </span>
          </div>
          <div className="assessment-mini">
            <Sun size={32} />
            <span>
              THE FUTURE
              <br />
              <strong>LOOKS BRIGHT.</strong>
            </span>
          </div>
        </div>
        <section className="question-card solar-question-card">
          <CustomerSurvey />
        </section>
      </section>
      <footer className="solar-footer">
        <a className="solar-wordmark" href="#customer">
          <span className="te-logo">
            <img src="/assets/terawatt-logo.png" alt="Terawatt Energy" />
          </span>
        </a>
        <p>พลังงานสะอาด เริ่มต้นได้ที่คุณ</p>
        <div>
          <a href="#epc">
            EPC Portal <ArrowUpRight size={12} />
          </a>
          <a href="#admin">
            ผู้ดูแลระบบ <ArrowUpRight size={12} />
          </a>
          <small>© {new Date().getFullYear()} Terawatt</small>
        </div>
      </footer>
    </div>
  );
}
