import os
import librosa
import librosa.display
import numpy as np
import soundfile as sf
import matplotlib.pyplot as plt

def griffin_lim(magnitude, n_iter=2, alpha=0.99, lambda_=0.1):
    # Initialize the phase randomly
    phase = np.exp(2j * np.pi * np.random.rand(*magnitude.shape))
    S = magnitude * phase

    for i in range(n_iter):
        # Inverse STFT
        y = librosa.istft(S)

        # STFT
        S = librosa.stft(y)

        # Update the magnitude
        S = magnitude * np.exp(1j * np.angle(S))

        # Apply alpha and lambda
        S = (1 / (1 + lambda_)) * (S + (lambda_ / (1 + lambda_)) * magnitude * np.exp(1j * np.angle(S)))

    return librosa.istft(S)

def process(y, sr, file_name, subdir):
    # Compute the Short-Time Fourier Transform (STFT)
    D = librosa.stft(y)
    magnitude = np.abs(D)  # magnitude spectrum

    # Apply the custom Griffin-Lim algorithm
    reconstructed_audio = griffin_lim(magnitude, n_iter=2, alpha=0.99, lambda_=0.01)

    # Create output path in gla/ folder
    gla_dir = os.path.join(subdir.replace('NOIZEUS', 'gla'))
    os.makedirs(gla_dir, exist_ok=True)
    save_path = os.path.join(gla_dir, file_name)

    # Save the reconstructed audio
    sf.write(save_path, reconstructed_audio, sr)

    # # Plot waveform
    # plt.figure(figsize=(10, 4))
    # librosa.display.waveshow(reconstructed_audio, sr=sr)
    # plt.title(f"Waveform: {file_name}")
    # plt.savefig(os.path.join(gla_dir, f"{file_name}_waveform.png"), dpi=300)
    # plt.show()

    # # Plot spectrogram
    # mel = librosa.feature.melspectrogram(
    #     y=reconstructed_audio,
    #     sr=sr,
    #     n_fft=2048,
    #     hop_length=512,
    #     window='hann',
    #     power=1.0,
    #     n_mels=256
    # )
    # mel_db = librosa.power_to_db(mel, ref=np.max)
    # mel_db[mel_db < -10] = -10  # Power thresholding
    # plt.figure(figsize=(10, 2))
    # librosa.display.specshow(mel_db, x_axis='time', y_axis='mel', sr=sr, cmap='viridis')
    # plt.colorbar(format='%+2.0f dB')
    # plt.title(f"Spectrogram: {file_name}")
    # plt.savefig(os.path.join(gla_dir, f"{file_name}_spectrogram.png"), dpi=300)
    # plt.show()

    return reconstructed_audio


audio_data = {}

for subdir, dirs, files in os.walk('./NOIZEUS/'):
    if os.path.basename(subdir) == 'kalm':
        print(f"Visiting: {subdir}")
        for file in files:
            if file.endswith('_kalm.wav'):
                file_path = os.path.join(subdir, file)
                data, sr = librosa.load(file_path)
                audio_data[file] = {
                    'sample_rate': sr,
                    'data': data
                }

                print(f"Processing {file}...")
                reconstructed_audio = process(data, sr, file, subdir)
                print(f"Finished processing {file}.")

                # Build the output path by replacing 'NOIZEUS' with 'part2' and 'kalm' with 'gla'
                output_dir = subdir.replace('NOIZEUS', 'part2').replace('kalm', 'gla')
                os.makedirs(output_dir, exist_ok=True)

                # Replace '_kalm.wav' with '_gla.wav' in filename
                gla_filename = file.replace('_kalm.wav', '_gla.wav')
                save_path = os.path.join(output_dir, gla_filename)

                # Save the reconstructed audio
                sf.write(save_path, reconstructed_audio, sr)
                print(f"Saved output to: {save_path}")


