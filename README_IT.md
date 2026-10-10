# Pipeline di Analisi di Missione CubeSat & Bilancio Energetico EPS

Pipeline automatizzata che integra **MATLAB** con **NASA GMAT** (in modalità batch da riga di comando) per l'analisi orbitale di CubeSat in orbita bassa (LEO).

Il workflow propaga l'orbita ad alta precisione considerando le perturbazioni da geopotenziale ($J_2$, degree/order 4x4), resistenza atmosferica (MSISE-90), perturbazioni gravitazionali di Sole e Luna e pressione di radiazione solare. Calcola le finestre di visibilità verso stazioni di terra e simula la carica e scarica delle batterie di bordo.

---

## Specifiche della Missione

* **Orbita:** Eliosincrona (SSO) a 500 km di quota ($i = 97.4^\circ$, $e = 0.001$).
* **Piattaforma:** CubeSat 3U ($4\text{ kg}$, sezione resistente $0.03\text{ m}^2$).
* **Stazione di Terra:** Nord Italia (Malo/Vicenza), maschera minima d'orizzonte $10^\circ$.
* **Sottosistema Elettrico (EPS):** Batteria da $40\text{ Wh}$, generazione solare di picco $12\text{ W}$, carico di bordo in ombra $4.5\text{ W}$.

---

## Risultati Ottenuti

![Grafici di Simulazione](mission_analysis_plot.png)

* **Rapporto Luce/Ombra:** 63.3% Sole, 36.2% Umbra (circa 34 minuti di eclisse per orbita da 94 minuti).
* **Stato della Batteria:** SoC minimo del 93.3% (DoD massimo del 6.7%), garantendo ampia sicurezza contro il degrado ciclico delle celle.
* **Passaggi Utili:** 7 passaggi in 48 ore con finestre di contatto fino a 6.2 minuti ed elevazione massima di 58.5°.
