# Terms of use

- **Draft:** needs review by the supervisor (legal content) and a native Arabic speaker before merge.
- **Two texts:**
  - `terms-v1`: for patients, in the Android app (iltiam/iltiam-mobile#44);
  - `staff-policies-v1`: for doctors, clinic admins and Super Admins, accepted when they activate their account on the web (iltiam/iltiam-web#29). It replaces the draft in iltiam-web `src/pages/public/policyText.ts`. The backend records the accepted version in `policies_version` (setting `SYSTEM_POLICIES_VERSION`).
- **Placeholders:** `<CONTROLLER>` (**TO CONFIRM, TC-1**) and `<EFFECTIVE_DATE>`. Governing law, liability and disclaimer wording: **TO CONFIRM (TC-24).** Patients under 18: **TO CONFIRM (TC-16).**

## `terms-v1`: patients

### English

**ILTIAM terms of use for patients** (`terms-v1`, effective `<EFFECTIVE_DATE>`)

1. **What ILTIAM is.** ILTIAM helps you and your clinic follow your wound: you send photos, an AI model measures the wound, and your doctor reviews the results, writes notes and plans your care. The service is provided by `<CONTROLLER>` for your clinic.
2. **Not for emergencies.** ILTIAM is not an emergency service, and messages may not be read at once. If your wound gets much worse, bleeds heavily, or you feel very unwell, call emergency services (997) or go to the nearest emergency department (**TO CONFIRM, TC-29**).
3. **The AI supports your doctor.** AI results are measurements, not a diagnosis. Your doctor decides your care.
4. **Your account.** Your clinic creates your account. Keep your password and codes to yourself; ILTIAM staff will never ask for them. Tell your clinic if your phone number changes or if you think someone used your account.
5. **What you agree to do.** Give correct information; send only photos of your own wound; use messages for your care only; don't try to reach data that isn't yours or disrupt the service.
6. **Your data.** How we use and protect your data is in the privacy notice (`privacy-notice-v1`). AI analysis and the feedback dataset need your separate consent (`ai-consent-v1`, `feedback-consent-v1`), which you can withdraw at any time.
7. **Availability.** We work to keep ILTIAM available, but it may stop for maintenance or faults. Photos you take without a connection are sent when the connection returns.
8. **Ending.** You can ask for your data to be deleted at any time (Profile → Privacy). Medical records are kept as the privacy notice explains.
9. **Changes.** When these terms change, they get a new version and we show it to you in the app before you continue.
10. **Law.** **TO CONFIRM (TC-24):** these terms are governed by the laws of the Kingdom of Saudi Arabia.
11. **Contact.** `privacy@iltiamcare.com`.

### العربية

**شروط استخدام التئام للمرضى** (`terms-v1`، تسري من `<EFFECTIVE_DATE>`)

١. **ما هو التئام.** يساعدك التئام أنت وعيادتك على متابعة جرحك: ترسل الصور، ويقيس نموذج ذكاء اصطناعي الجرح، ويراجع طبيبك النتائج ويكتب ملاحظاته ويخطط لرعايتك. تقدّم الخدمةَ `<CONTROLLER>` لصالح عيادتك.

٢. **ليس للطوارئ.** التئام ليس خدمة طوارئ، وقد لا تُقرأ الرسائل فوراً. إذا ساءت حالة جرحك كثيراً، أو نزف بشدة، أو شعرت بتعب شديد، فاتصل بالطوارئ (997) أو توجّه إلى أقرب قسم طوارئ (**TO CONFIRM, TC-29**).

٣. **الذكاء الاصطناعي يساعد طبيبك.** نتائج الذكاء الاصطناعي قياسات وليست تشخيصاً، وطبيبك هو من يقرّر رعايتك.

٤. **حسابك.** تُنشئ عيادتك حسابك. احتفظ بكلمة المرور والرموز لنفسك، ولن يطلبها منك موظفو التئام أبداً. أبلغ عيادتك إذا تغيّر رقم جوالك أو اشتبهت في أن أحداً استخدم حسابك.

٥. **ما توافق عليه.** أن تقدّم معلومات صحيحة، وألّا ترسل إلا صور جرحك أنت، وأن تستخدم الرسائل لرعايتك فقط، وألّا تحاول الوصول إلى بيانات ليست لك أو تعطيل الخدمة.

٦. **بياناتك.** يشرح إشعار الخصوصية (`privacy-notice-v1`) كيف نستخدم بياناتك ونحميها. يحتاج تحليل الذكاء الاصطناعي ومجموعة بيانات التحسين إلى موافقتك المنفصلة (`ai-consent-v1` و `feedback-consent-v1`)، ويمكنك سحبها في أي وقت.

٧. **التوفّر.** نعمل على إبقاء التئام متاحاً، لكنه قد يتوقف للصيانة أو بسبب أعطال. تُرسل الصور التي تلتقطها دون اتصال عند عودة الاتصال.

٨. **إنهاء الاستخدام.** يمكنك طلب حذف بياناتك في أي وقت (الملف الشخصي ← الخصوصية). تُحفظ السجلات الطبية كما يوضّح إشعار الخصوصية.

٩. **التغييرات.** عند تغيير هذه الشروط تصدر بإصدار جديد ونعرضها عليك في التطبيق قبل المتابعة.

١٠. **النظام المطبّق.** **TO CONFIRM (TC-24):** تخضع هذه الشروط لأنظمة المملكة العربية السعودية.

١١. **التواصل.** `privacy@iltiamcare.com`.

## `staff-policies-v1`: doctors, clinic admins and Super Admins

### English

**ILTIAM policies for staff** (`staff-policies-v1`, effective `<EFFECTIVE_DATE>`)

1. **Your account is personal.** Don't share your password, codes or authenticator app. Sign out on shared computers.
2. **Need to know.** Use your access only for your work on ILTIAM. Open a patient's record only when your work requires it. Every view and change of patient data is recorded in the audit log, and patients can see who viewed their record.
3. **Patient data is protected** under the Saudi Personal Data Protection Law. Don't copy, photograph, download or send patient data outside ILTIAM except through its own features (reports, prescriptions, exports).
4. **The AI supports, it doesn't decide.** ILTIAM supports clinical decisions. It does not diagnose and does not replace clinical judgement. Review AI results before relying on them.
5. **Records stay.** Notes and prescriptions you sign can't be deleted, and your account is deactivated, not deleted, when you leave, so that your records keep their author (**TO CONFIRM, TC-17**).
6. **Report at once.** Tell the ILTIAM team straight away (`security@iltiamcare.com`) if you think your account or any data was exposed.
7. **Changes.** When these policies change, you accept the new version at your next sign-in.

### العربية

**سياسات التئام للموظفين** (`staff-policies-v1`، تسري من `<EFFECTIVE_DATE>`)

١. **حسابك شخصي.** لا تشارك كلمة المرور أو الرموز أو تطبيق المصادقة مع أحد، وسجّل الخروج من الأجهزة المشتركة.

٢. **الاطّلاع بقدر الحاجة.** استخدم صلاحياتك لعملك على التئام فقط، ولا تفتح سجل مريض إلا عند حاجة عملك إليه. يُسجَّل كل اطّلاع على بيانات المرضى وكل تعديل عليها في سجل التدقيق، ويستطيع المرضى معرفة من اطّلع على سجلاتهم.

٣. **بيانات المرضى محمية** بموجب نظام حماية البيانات الشخصية السعودي. لا تنسخ بيانات المرضى ولا تصوّرها ولا تنزّلها ولا ترسلها خارج التئام إلا عبر ميزاته (التقارير والوصفات والتصدير).

٤. **الذكاء الاصطناعي يساعد ولا يقرّر.** يدعم التئام القرار السريري، ولا يشخّص ولا يحلّ محلّ الحكم السريري. راجع نتائج الذكاء الاصطناعي قبل الاعتماد عليها.

٥. **السجلات تبقى.** لا يمكن حذف الملاحظات والوصفات التي توقّعها، ويُعطَّل حسابك ولا يُحذف عند مغادرتك، لتبقى سجلاتك منسوبة إليك (**TO CONFIRM, TC-17**).

٦. **أبلغ فوراً.** أبلغ فريق التئام فوراً (`security@iltiamcare.com`) إذا اشتبهت في كشف حسابك أو أي بيانات.

٧. **التغييرات.** عند تغيير هذه السياسات توافق على الإصدار الجديد عند تسجيل دخولك التالي.
