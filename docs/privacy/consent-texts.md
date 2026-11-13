# Consent texts

- **Issue:** #6. **Draft:** needs review by the supervisor and a native Arabic speaker before merge.
- **Version IDs:** each text has one. The apps show the words of the ID they record. **A changed text gets a new ID** (`ai-consent-v2`); the old one stays here, so a past consent can always be read in the words the patient saw.
- **Legal basis:** explicit consent. **TO CONFIRM (TC-3 for AI analysis, TC-4 for the feedback dataset).** Who consents for a minor or a patient who can't: **TO CONFIRM (TC-16).**
- **Shown by:** the doctor's new patient form on the web (iltiam/iltiam-web#29) and the app's Profile → Privacy screen (iltiam/iltiam-mobile#44).

| ID | Consent | Default | Recorded by the backend as |
|---|---|---|---|
| `ai-consent-v1` | AI analysis of wound photos | asked at registration | `Patient.ai_analysis_consent`, `ai_analysis_consent_at` |
| `feedback-consent-v1` | the AI feedback dataset | **off** unless the patient turns it on | `Patient.ai_feedback_consent`, `ai_feedback_consent_at` |

## `ai-consent-v1`: AI analysis of wound photos

### English

**Title:** AI analysis of your wound photos

ILTIAM uses an artificial intelligence (AI) model to measure your wound from the photos you or your care team take: its size, the types of tissue and a risk level. The results help your doctor follow how your wound heals. Your doctor reviews them. The AI does not diagnose and does not replace your doctor.

Your photos and results are stored on servers in Saudi Arabia (Riyadh). Only you and your care team can see them.

This consent is optional. Without it, your photos are still stored and your doctor still sees them, but the AI does not analyse them.

You can withdraw this consent at any time in the app (Profile → Privacy). Withdrawing applies to new photos. Results made before stay in your record.

**Checkbox:** I agree that ILTIAM analyses my wound photos with AI.

**Withdraw dialog:** Stop AI analysis? Your new photos will be stored for your doctor, but not analysed. Results made before stay in your record. **Buttons:** Stop AI analysis / Cancel

### العربية

**العنوان:** تحليل صور جرحك بالذكاء الاصطناعي

يستخدم التئام نموذج ذكاء اصطناعي لقياس جرحك من الصور التي تلتقطها أنت أو فريق رعايتك: مساحته، وأنواع الأنسجة فيه، ومستوى الخطورة. تساعد هذه النتائج طبيبك على متابعة شفاء جرحك، ويراجعها طبيبك. الذكاء الاصطناعي لا يشخّص ولا يحلّ محلّ طبيبك.

تُحفظ صورك ونتائجك على خوادم داخل المملكة العربية السعودية (الرياض)، ولا يطّلع عليها إلا أنت وفريق رعايتك.

هذه الموافقة اختيارية. إذا لم توافق، تُحفظ صورك ويراها طبيبك، لكن لا يحلّلها الذكاء الاصطناعي.

يمكنك سحب هذه الموافقة في أي وقت من التطبيق (الملف الشخصي ← الخصوصية). يسري السحب على الصور الجديدة، وتبقى النتائج السابقة في سجلك.

**مربع الاختيار:** أوافق على أن يحلّل التئام صور جرحي بالذكاء الاصطناعي.

**نافذة السحب:** إيقاف تحليل الذكاء الاصطناعي؟ ستُحفظ صورك الجديدة لطبيبك دون تحليلها، وتبقى النتائج السابقة في سجلك. **الأزرار:** إيقاف التحليل / إلغاء

## `feedback-consent-v1`: the AI feedback dataset

### English

**Title:** Help improve the AI

With your permission, when your doctor corrects an AI result for one of your photos, the photo, the corrected wound outline and the corrected values may be added to a dataset used to improve ILTIAM's AI model.

Your name, phone number and other details that identify you are removed before the data leaves the system. A wound photo can still show marks on your skin.

This is optional and off unless you turn it on. It does not change your care in any way.

You can withdraw at any time in the app (Profile → Privacy). Your corrections are then left out of every later dataset. Data already used to train a model can't be removed from that model.

**Checkbox:** I agree that my corrected wound results, without details that identify me, are used to improve the AI.

**Withdraw dialog:** Stop sharing your corrected results to improve the AI? They will be left out of every later dataset. **Buttons:** Stop sharing / Cancel

### العربية

**العنوان:** ساعدنا في تحسين الذكاء الاصطناعي

بإذنك، عندما يصحّح طبيبك نتيجة الذكاء الاصطناعي لإحدى صورك، قد تُضاف الصورة وحدود الجرح المصحّحة والقيم المصحّحة إلى مجموعة بيانات تُستخدم لتحسين نموذج الذكاء الاصطناعي في التئام.

يُحذف اسمك ورقم جوالك وكل ما يدلّ على هويتك قبل أن تخرج البيانات من النظام. وقد تُظهر صورة الجرح علامات في جلدك.

هذه الموافقة اختيارية ومتوقفة ما لم تفعّلها، ولا تؤثر على رعايتك بأي شكل.

يمكنك سحبها في أي وقت من التطبيق (الملف الشخصي ← الخصوصية)، وعندها لا تُضاف تصحيحاتك إلى أي مجموعة بيانات لاحقة. أما البيانات التي استُخدمت سابقاً في تدريب نموذج فلا يمكن إزالتها منه.

**مربع الاختيار:** أوافق على استخدام نتائج جرحي المصحّحة، دون ما يدلّ على هويتي، لتحسين الذكاء الاصطناعي.

**نافذة السحب:** إيقاف مشاركة نتائجك المصحّحة لتحسين الذكاء الاصطناعي؟ لن تُضاف إلى أي مجموعة بيانات لاحقة. **الأزرار:** إيقاف المشاركة / إلغاء

## Recording

- **Today** the backend records on or off and the time (`PATCH /api/patients/me/consents/`, and the registration form). Every change is audited. Withdrawing needs a fresh identity check (step-up).
- **Not yet recorded: the version ID.** Backend follow-up: store `ai_analysis_consent_version` and `ai_feedback_consent_version` with each change, and return them in `GET /api/patients/me/consents/`, so the apps and an audit can tell which words a patient agreed to.
- **When a text changes** (a new ID): the apps show the new text to patients who agreed to an older ID, and ask again. Until they answer, the older consent stays in force. **TO CONFIRM (TC-26)** whether a new consent is needed for every wording change or only for a change of purpose.
- The proof of what each right does is in the [rights map](rights-map.md#5-withdraw-consent).
