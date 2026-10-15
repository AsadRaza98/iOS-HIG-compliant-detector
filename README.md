# iOS-HIG-compliant-detector
An iOS app built on top of a machine learning model to detect how much another ios app follows human interface guidelines suggested by Apple

# Motivaton 
From a coder's pov, an application's functionality is all that matters. If an app is functioning well, it serves the purpose. But users seldom use a functioning application if it's not pleasing to the eyes and designed in a user friendly way. To ensure that, Apple recommends Human Interface Guidelines for developers to follow which includes the color contrast, safe spaces, text fonts and sizes, and so-on. 

This repository and code is written to develop such an app

# Dataset
Finding the dataset to train the model was the biggest challenge. The only publicly available dataset for iOS screens is the VINS dataset published in 2021. Filtered to the iOS screens, only 1200 screens could be extracted from there. The iOS version back in 2021 and the HIG rules have all changed completely since then.
Mobbin (https://mobbin.com) promises recent screenshots of top apps but is a paid tool. 

Examples from the VINS dataset

<img width="222" height="483" alt="IMG_3690" src="https://github.com/user-attachments/assets/3a4af3f8-a8ee-406d-b87a-ddc87125158f" />

<img width="222" height="483" alt="IMG_855910" src="https://github.com/user-attachments/assets/2d81f11a-e21a-47b3-9641-75171a3cbb52" />

# Workflow
1. Apple's built-in model Vision to detect text in a screenshot
2. Gather dataset for the machine learning (VINS Dataset)
3. Train the transfer learning model on Create ML (Failed)
4. Train a machine learning model YOLO on Python to detect the different visual elements present on the screen.
5. Import the trained model on Swift using Core ML
6. Feed the HIG rules to another model
7. Highlight problems and provide suggestions and improvement to the uploaded screenshots

# Model Results

<img width="222" height="483" alt="IMG_4922" src="https://github.com/user-attachments/assets/4534d280-05af-4421-92f9-ad4a8b7fe792" />

<img width="222" height="483" alt="IMG_4913" src="https://github.com/user-attachments/assets/1cd73237-4df3-4b10-91d5-59735a1c3b70" />


# Final Application Screenshot
<img width="222" height="483" alt="IMG_4996" src="https://github.com/user-attachments/assets/f6dfd048-0527-4c6c-8319-e38d3a0938c9" />
<img width="222" height="483" alt="IMG_4995" src="https://github.com/user-attachments/assets/b09f5069-6f5f-49f4-8452-78f4dacfebfc" />
<img width="222" height="483" alt="IMG_4994" src="https://github.com/user-attachments/assets/4d834566-cd95-4604-b30d-ca0101aa97e4" />
<img width="222" height="483" alt="IMG_4993" src="https://github.com/user-attachments/assets/2770bb08-35ec-432c-b5e8-708bd89632e7" />

# A different approach
Since VINS dataeset is from 2021, it was bound to not detect navigation bar and tab bar in the perfect way since iOS has upgraded a lot. The way around I could find for this problem was to produce dataset by myself on Swift. I generated 3000 screenshots of random screens just to be able to train the YOLO model on screen elements as per the latest iOS and Swift. The result was much better than the YINS dataset

## Synthetic Dataset
<img width="222" height="483" alt="synth_00002633" src="https://github.com/user-attachments/assets/09f76445-e87f-4636-a72b-b59ccf63d4e3" />
<img width="222" height="483" alt="synth_00002621" src="https://github.com/user-attachments/assets/a58aeb0e-faa8-4448-8999-e711d10cd700" />
<img width="222" height="483" alt="synth_00002618" src="https://github.com/user-attachments/assets/2b5b20df-71ad-40e4-a925-13b731b297c2" />

## Results
<img width="222" height="483" alt="IMG_5004" src="https://github.com/user-attachments/assets/59f792ca-b8f6-43fa-9a11-1bf52c55435f" />
<img width="222" height="483" alt="IMG_5003" src="https://github.com/user-attachments/assets/b4b771b3-50ac-4881-862f-ad2b9944bc0e" />
<img width="222" height="483" alt="IMG_5001" src="https://github.com/user-attachments/assets/87fd5f0f-cba3-42ac-b8ea-f290ca4259f2" />
<img width="222" height="483" alt="IMG_4999" src="https://github.com/user-attachments/assets/8372f073-f94e-49f5-99b9-0bd9c10db2af" />


# Resources
1. The latest human interface guidelines can be found on https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://developer.apple.com/design/human-interface-guidelines&ved=2ahUKEwiNi9-CxLmXAxX6_QIHHTS_BHMQFnoECB8QAQ&usg=AOvVaw0rKy6v8SnXBL92UJdGXdux
