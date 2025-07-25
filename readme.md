Dependencies:
NOIZEUS Corpus downloaded and in the main directory.

Assumptions:
wav file is a high fidelity representation of speech.
16kHz is a sufficient Nyqyuist fs


1. Run findOrder.m (wav file)
2. Run griffinLimTune.py (wav file)
3. Run kalman_speech_varQ.m (Nx1)
4. Run pesqScore.py (Input filter-> VAD-> MOS-LAQ)


Overleaf Comments on PESQ compared to other literature
Try reverseing the order in series of GLA vs. Kalman, so Kalman first
Try different values of Qnom
Make Das' kalman script more readable! ChatGPT



Optimization: How is PESQ Calculated? Not hyubrid algorithm

Proof: PESQ increases (delta) under certain setup or conditions of paremters optimized:
- SR
- window size
- bit depth


Visualization plots?