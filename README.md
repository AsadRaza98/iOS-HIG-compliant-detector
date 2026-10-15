# iOS-HIG-compliant-detector
An iOS app built on top of a machine learning model to detect how much another ios app follows human interface guidelines suggested by Apple

# Motivaton 
From a coder's pov, an application's functionality is all that matters. If an app is functioning well, it serves the purpose. But users seldom use a functioning application if it's not pleasing to the eyes and designed in a user friendly way. To ensure that, Apple recommends Human Interface Guidelines for developers to follow which includes the color contrast, safe spaces, text fonts and sizes, and so-on. 

This repository and code is written to develop such an app

# Dataset
Finding the dataset to train the model was the biggest challenge. The only publicly available dataset for iOS screens is the VINS dataset published in 2021. Filtered to the iOS screens, only 1200 screens could be extracted from there. The iOS version back in 2021 and the HIG rules have all changed completely since then.
Mobbin (https://mobbin.com) promises recent screenshots of top apps but is a paid tool. 

Couple of examples from the VINS dataset

<img width="1242" height="2208" alt="IMG_0754" src="https://github.com/user-attachments/assets/a153922f-942f-4920-aad5-b70eddb37bb3" />


# Workflow
1. Apple's built-in model Vision to detect text in a screenshot
2. Gather dataset for the machine learning (VINS Dataset)
3. Train the transfer learning model on Create ML (Failed)
4. Train a machine learning model YOLO on Python to detect the different visual elements present on the screen.
5. Import the trained model on Swift using Core ML
6. Feed the HIG rules to another model
7. Highlight problems and provide suggestions and improvement to the uploaded screenshots

# Resources
1. The latest human interface guidelines can be found on https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://developer.apple.com/design/human-interface-guidelines&ved=2ahUKEwiNi9-CxLmXAxX6_QIHHTS_BHMQFnoECB8QAQ&usg=AOvVaw0rKy6v8SnXBL92UJdGXdux
