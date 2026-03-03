# 📚 EduLlama — Content Directory

Drop your NCERT/CBSE PDF files into the correct folder below.
The backend auto-discovers every PDF on startup — no code changes needed.

## Naming tip
Keep filenames clean and descriptive — they become the chapter name shown in the app.
**Good:** `Chapter1_Crop_Production.pdf`
**Avoid:** `ch1(final)v2.pdf`

---

## Grade 6

### Science
```
content/Grade6/Science/
```
Suggested files: Chapter1_Food.pdf, Chapter2_Components_of_Food.pdf, ...

### Maths
```
content/Grade6/Maths/
```
Suggested files: Chapter1_Knowing_Numbers.pdf, Chapter2_Whole_Numbers.pdf, ...

### English
```
content/Grade6/English/
```
Suggested files: Chapter1_Who_Did_Patricks_Homework.pdf, ...

### Social Science
```
content/Grade6/Social_Science/
```
Suggested files: Chapter1_What_Where_How.pdf, ...

---

## Grade 7

### Science
```
content/Grade7/Science/
```
Existing science PDFs can be moved here from `science_directory/`.

### Maths
```
content/Grade7/Maths/
```

### English
```
content/Grade7/English/
```

### Social Science
```
content/Grade7/Social_Science/
```

---

## Grade 8

### Science
```
content/Grade8/Science/
```

### Maths
```
content/Grade8/Maths/
```

### English
```
content/Grade8/English/
```

### Social Science
```
content/Grade8/Social_Science/
```

---

> ⚠️ Restart the backend (`python app.py`) after adding new PDFs so they get indexed into ChromaDB.
