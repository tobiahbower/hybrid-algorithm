import os
import librosa
import numpy as np
import csv
from pesq import pesq

def calculate_pesq_score(x, y):
    sr_pesq_req = 16000  # Hz

    # Load and resample with librosa
    X, _ = librosa.load(x, sr=sr_pesq_req, mono=True)
    Y, _ = librosa.load(y, sr=sr_pesq_req, mono=True)

    # Convert to int16 format
    X = (X * 32767).astype(np.int16)
    Y = (Y * 32767).astype(np.int16)

    # Compute PESQ score
    score = pesq(sr_pesq_req, X, Y, mode='wb')
    return score



results_wav = []
base_dir = './gla'  # Root directory containing folders like 'airport_0dB'

for speech_dir in os.listdir(base_dir):
    wav_folder = os.path.join(base_dir, speech_dir, 'wav')
    if os.path.isdir(wav_folder):
        for file in os.listdir(wav_folder):
            if file.endswith('.wav'):
                wav_file = os.path.join(wav_folder, file)

                # Get clean reference path
                ref_file = os.path.join('./NOIZEUS', speech_dir, 'wav', file)

                try:
                    score = calculate_pesq_score(ref_file, wav_file)
                    results_wav.append([file, wav_file, ref_file, score])
                except Exception as e:
                    print(f"Error processing {file}: {e}")
                    results_wav.append([file, wav_file, ref_file, f"Error: {e}"])

# Save wav results
with open('pesq_scores_wav.csv', mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Filename', 'WAV Path', 'NOIZEUS Path', 'PESQ Score'])
    writer.writerows(results_wav)

results_kalm = []

for speech_dir in os.listdir(base_dir):
    kalm_folder = os.path.join(base_dir, speech_dir, 'kalm')
    if os.path.isdir(kalm_folder):
        for file in os.listdir(kalm_folder):
            if file.endswith('.wav'):
                kalm_file = os.path.join(kalm_folder, file)

                # Fix filename to match reference (remove '_kalm')
                ref_name = file.replace('_kalm', '')  
                ref_file = os.path.join('./NOIZEUS', speech_dir, 'wav', ref_name)

                try:
                    score = calculate_pesq_score(ref_file, kalm_file)
                    results_kalm.append([file, kalm_file, ref_file, score])
                except Exception as e:
                    print(f"Error processing {file}: {e}")
                    results_kalm.append([file, kalm_file, ref_file, f"Error: {e}"])

# Save kalm results
with open('pesq_scores_kalm.csv', mode='w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['Filename', 'Kalm Path', 'NOIZEUS Path', 'PESQ Score'])
    writer.writerows(results_kalm)