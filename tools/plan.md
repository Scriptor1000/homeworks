## Dokumentation
1. Mithilfe von `dart run index_generator build` die Libaries bauen
2. Durch `dart doc` die Dokomentation in `/doc/api` bauen
3. Die Dokumentation als Artifakt hochladen

## Berichtsheft
1. Mit `pip install -r requirements.txt` die Pakete installiere
2. Mit `python create_report.py` mit der ENV GITHUB_TOKEN das Berichtsheft als .tex erstellen.
3. Mithilfe von `xu-cheng/latex-action@v4` die .tex in GitHub Actions zu PDF bauen
4. Dieses PDF als git Artefact hochladen 

## Github Pages
1. Beide Artefakte herunterladen
    - dabei die PDF direkt neben der index.html 
2.  Den Ordner auf Github Pages veröffentlichen
