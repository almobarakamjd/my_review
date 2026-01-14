# وثيقة مواصفات مشروع "المراجع الذكي" (Smart Reviewer)

## 1. نظرة عامة
تطبيق موبايل (أندرويد) يهدف لضمان مراجعة الطلاب لدروسهم يومياً من خلال "قفل" الهاتف أو تقييد استخدامه حتى يتم الإجابة على مجموعة من الأسئلة المنهجية، مع وجود إشراف أبوي ومراعاة لأوقات العطلات.

## 2. الميزات الرئيسية
1.  **نظام القفل (Kiosk/Overlay):** واجهة تظهر فوق التطبيقات الأخرى تمنع استخدام الهاتف.
2.  **المراجعة اليومية:** أسئلة منهجية (اختيارات متعددة) تعتمد على مرحلة الطالب، عددها 10 أسئلة (7 منهجية عامة + 3 رياضيات/جبر).
3.  **تقارير التقدم (Result):** عرض نتيجة شهرية (شهادة) ورسوم بيانية لتقدم الطالب (أسبوعي/شهري/سنوي).
4.  **حساب ولي الأمر:** إمكانية تجاوز القفل بكلمة مرور الأب.
5.  **الربط بمنصة مدرستي:** التوجيه التلقائي للمنصة بعد إتمام الاختبار بنجاح.
6.  **التعرف على العطلات:** تعطيل النظام تلقائياً في أيام العطل الرسمية (السعودية).
7.  **التحقق من الهوية:** ربط التطبيق باسم الطالب وجهازه (Device ID).

---

## 3. هيكلية قاعدة البيانات (Backend - MySQL)

مقترح للجداول التي سيتم إنشاؤها على الاستضافة الخاصة بك:

```sql
-- جدول المستخدمين (للطلاب والآباء)
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL,
    user_type ENUM('student', 'parent') NOT NULL,
    device_id VARCHAR(255), -- لربط جهاز الطالب
    parent_id INT, -- لربط الطالب بوالده
    grade_level VARCHAR(50), -- المرحلة الدراسية (مثلاً: متوسط، ثانوي)
    password_hash VARCHAR(255), -- للأب فقط
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول الأسئلة
CREATE TABLE questions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    grade_level VARCHAR(50), -- لتصنيف الأسئلة حسب المرحلة
    subject VARCHAR(100), -- المادة (رياضيات، علوم...)
    question_text TEXT NOT NULL,
    options JSON NOT NULL, -- مثال: ["4", "5", "6", "9"]
    correct_answer VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول السجلات اليومية (لمعرفة هل أتم الطالب الاختبار)
CREATE TABLE daily_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    log_date DATE,
    status ENUM('pending', 'completed', 'bypassed_by_parent') DEFAULT 'pending',
    score INT,
    details JSON, -- تفاصيل الدرجات حسب المادة (مثلاً: {"math": 3, "science": 2})
    FOREIGN KEY (student_id) REFERENCES users(id)
);

-- جدول العطلات
CREATE TABLE holidays (
    id INT AUTO_INCREMENT PRIMARY KEY,
    holiday_date DATE NOT NULL,
    description VARCHAR(255)
);
```

---

## 4. تصميم الـ API (JSON Response Structure)

### أ. التحقق من الحالة (Check Status)
يطلبه التطبيق عند فتح الشاشة للتأكد هل يجب تفعيل القفل أم لا.

**Request:**
```json
{
  "endpoint": "check_status",
  "student_device_id": "android_12345",
  "current_date": "2023-10-27"
}
```

### ب. جلب الأسئلة (Get Quiz)
يرجع 10 أسئلة (7 عامة + 3 رياضيات).

### ج. تسجيل النتيجة (Submit Quiz)
يسجل الدرجة النهائية وتفاصيلها.
**Request:**
```json
{
  "action": "submit_quiz",
  "student_id": 123,
  "score": 9,
  "details": { "breakdown": {"math": 3, "history": 6} }
}
```

### د. جلب التقرير (Get Report)
**Request:**
```json
{
  "action": "get_report",
  "student_id": 123,
  "period": "week" // or 'month', 'year'
}
```
**Response:**
Returns list of logs with scores and dates.

---

## 5. منطق عمل التطبيق (Flow)
1.  **Start Up:** التطبيق يعمل كـ Service عند بدء التشغيل.
2.  **Check:** يتصل بالـ API للتحقق من `lock_required`.
3.  **If Lock = True:** يفتح شاشة كاملة (Full Screen).
4.  **Action:**
    *   يحل الطالب 10 أسئلة (7 عام + 3 جبر).
    *   عند الانتهاء: يرسل النتيجة ويعرض صفحة النجاح ثم يفتح "مدرستي".
5.  **Reports:** يمكن للطالب فتح شاشة التقارير لمشاهدة "النتيجة" الشهرية والتقدم البياني.