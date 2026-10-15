// Collects the official McDonald's Deutschland nutrition values.
// mcdonalds.com blocks scripted downloads, so this runs in a normal browser:
//   1. open https://www.mcdonalds.com/de/de-de.html
//   2. paste this file into the developer console and wait for "fertig"
//   3. copy the printed lines into tools/restaurants/raw/mcdonalds.jsonl
//   4. python3 tools/restaurants/build_restaurants.py
// One line per product: [id, category, name, serving, kcal, protein, carbs, fat, sugar, fiber, saturatedFat, salt],
// each value as [portion value, unit, value per 100 g] exactly as published.
(async () => {
  const cats = ['burger', 'mcwrap', 'mccrispy', 'mcnuggets-fingerfood', 'veggie-und-plantbased', 'beilagen-extras',
    'fruehstueck', 'getraenke', 'desserts', 'mccafe', 'mcsmart-snacks', 'highlights'];
  const keep = ['primary_serving_size', 'energy_kcal', 'protein', 'carbohydrate', 'fat', 'sugar', 'fiber', 'saturated_fat', 'salt'];
  const pages = new Map();
  for (const c of cats) {
    const html = await (await fetch(`/de/de-de/produkte/alle-produkte/${c}.html`)).text();
    const doc = new DOMParser().parseFromString(html, 'text/html');
    for (const a of doc.querySelectorAll('a[href*="/product/"]')) {
      const path = new URL(a.getAttribute('href'), location.href).pathname;
      if (!pages.has(path)) pages.set(path, c);
    }
  }
  const lines = [];
  for (const [path, cat] of pages) {
    const page = await (await fetch(path)).text();
    const id = (page.match(/data-product-id="(\d+)"/) || [])[1];
    if (!id) continue;
    const item = (await (await fetch(`/dnaapp/itemDetails?country=DE&language=de&showLiveData=true&item=${id}`)).json()).item;
    if (!item) continue;
    const n = {};
    for (const x of item.nutrient_facts?.nutrient || []) n[x.nutrient_name_id] = x;
    lines.push(JSON.stringify([id, cat, item.item_marketing_name || item.item_name,
      ...keep.map(k => n[k] ? [n[k].value, n[k].uom, typeof n[k].hundred_g_per_product === 'object' ? null : n[k].hundred_g_per_product] : null)]));
    await new Promise(r => setTimeout(r, 150));   // be gentle
  }
  console.log(lines.join('\n'));
  console.log(`fertig: ${lines.length} Produkte`);
})();
