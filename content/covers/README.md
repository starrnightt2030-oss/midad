# أغلفة المحتوى

ارفع صورة الغلاف هنا باسم **معرّف العمل** نفسه، مثل:
`after-storm.jpg` أو `after-storm.png` أو `after-storm.webp`

- النسبة المثالية **٣:٤ (عمودي)**، والمقاس المقترح 900×1200 بكسل.
- الأداة (`tools/atheer_studio.py covers`) وسير عمل GitHub يقومان تلقائيًا بـ:
  ضبط المقاس، ضغط الصورة إلى JPG، وربطها بالعمل في `catalog.json`.
- لو لم ترفع غلافًا، يرسم التطبيق غلافًا فنيًا حسب قيمة `art` للعمل
  (storm, lantern, traveler, deepsea, mind, morning).
