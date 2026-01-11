# TODO — Projet AM-selfinj-x64-win11

Référence du cahier des charges : Projet d'analyse et d'injection de shellcode Windows 11 x64

---

## 0. Cadrage initial

- Lire intégralement le sujet et identifier les contraintes non négociables
- Lister les outils autorisés et interdits
- Définir le périmètre exact du shellcode attendu
- Choisir l'implémentation du shellcode :
  - assembleur NASM x86_64 Windows
  - ou C minimal compilé en PIC
- Créer l'arborescence de travail conforme :
  - compile.sh
  - shellcode.nasm ou shellcode.c
  - main.tpl.c
  - tmp/

---

## 1. Conception du shellcode

- Définir le comportement fonctionnel exact :
  - appel MessageBoxA(0, "this is a message", "this is a title", 0)
  - appel ExitProcess(0)
- Choisir la stratégie de résolution des API :
  - GetModuleHandle + GetProcAddress
  - ou PEB walk + parsing EAT
- Identifier les API nécessaires :
  - kernel32.LoadLibraryA ou LoadLibraryExA
  - kernel32.GetProcAddress
  - user32.MessageBoxA
  - kernel32.ExitProcess
- Implémenter la résolution dynamique des API
- Respecter strictement l'ABI Windows x64 :
  - registres RCX, RDX, R8, R9
  - shadow space de 0x20 bytes
- Assurer la position-indépendance du code
- Éviter toute référence à une adresse absolue
- Stocker les chaînes nécessaires de manière inline ou calculée
- Commenter chaque bloc logique du shellcode
- Tester le shellcode isolément en mémoire si possible

---

## 2. Implémentation du shellcode

- Écrire shellcode.nasm en x86_64
- Désactiver toute dépendance à la libc
- Gérer explicitement la pile et l'alignement
- Générer un binaire brut :
  - sortie attendue : tmp/1-shellcode.bin

---

## 3. Conversion du shellcode en tableau C

- Convertir tmp/1-shellcode.bin en tableau C
- Utiliser uniquement des outils autorisés :
  - xxd -i
  - od
  - r2
- Produire :
  - tmp/2-shellcode.bin.c-array
- Vérifier que le tableau est valide et exploitable
- Vérifier la taille exacte du shellcode

---

## 4. Template C (wrapper)

- Écrire main.tpl.c
- Prévoir un point d'injection clair pour le shellcode
- Allouer une zone mémoire exécutable :
  - VirtualAlloc ou équivalent
- Copier le shellcode dans la zone mémoire
- Exécuter le shellcode via un pointeur de fonction
- Ajouter des commentaires expliquant chaque étape
- Éviter toute dépendance inutile

---

## 5. Script compile.sh

### STEP 0 – Préparation

- Vérifier l'environnement
- Supprimer ./tmp si existant
- Recréer ./tmp proprement

### STEP 1 – Compilation shellcode

- Vérifier la présence de shellcode.nasm ou shellcode.c
- Compiler vers tmp/1-shellcode.bin
- Gérer les erreurs de compilation

### STEP 2 – Conversion C-array

- Convertir tmp/1-shellcode.bin
- Générer tmp/2-shellcode.bin.c-array
- Vérifier la cohérence du fichier généré

### STEP 3 – Génération du C final

- Injecter le C-array dans main.tpl.c
- Produire tmp/3-main.c
- Vérifier que le fichier est compilable

### STEP 4 – Compilation PE64

- Compiler tmp/3-main.c avec x86_64-w64-mingw32-gcc
- Générer tmp/4-pefile.exe
- Gérer toutes les erreurs possibles

### STEP 5 – Finalisation

- Copier tmp/4-pefile.exe vers ./pefile.exe
- Vérifier la présence du fichier final

---

## 6. Tests et validation

- Tester pefile.exe sur Windows 11 x64
- Vérifier l'apparition correcte de la MessageBox
- Vérifier le titre et le message exacts
- Vérifier la terminaison propre via ExitProcess
- Tester sans dépendance à des fichiers externes
- Tester plusieurs exécutions successives

---

## 7. Qualité et conformité

- Vérifier que tout le code est lisible et commenté
- Vérifier que le shellcode est facilement modifiable
- Vérifier que le build est 100 % automatisé
- Vérifier l'absence d'outils interdits
- Nettoyer tout code mort ou inutile

---

## 8. Documentation (optionnelle mais recommandée)

- Rédiger un README.md technique :
  - description du projet
  - architecture du build
  - description du shellcode
  - instructions de compilation
- Expliquer les choix techniques majeurs

---

## 9. Bonus (si temps disponible)

- Tester l'exécution avec Windows Defender actif
- Implémenter une obfuscation légère du shellcode
- Modifier la section d'injection dans le PE
- Ajouter un polymorphisme simple
- Documenter précisément ces mécanismes

---

## 10. Livraison finale

- Vérifier le contenu du livrable :
  - compile.sh
  - shellcode.nasm ou shellcode.c
  - main.tpl.c
  - pefile.exe
  - README.md (si présent)
- Compresser en .tar.gz ou .zip
- Vérifier une dernière fois l'exécution sous Windows 11
