Dependencies:
NOIZEUS Corpus downloaded and in the main directory.

Assumptions:
wav file is a high fidelity representation of speech.
16kHz is a sufficient Nyqyuist fs


1. Run findOrder.m (wav file)
2. Run griffinLimTune.py (wav file)
3. Run kalman_speech_varQ.m (Nx1)
4. Run pesqScore.py (Input filter-> VAD-> MOS-LAQ)