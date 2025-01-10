# README

This is a rails application that is currently set up to classify anchorages around the US coastline. The app could be generalized to classifiy images of pretty much any type, but I use it myself for finding anchorages where I can anchor my sailboat while we're traveling.

The app has a built-in classifier to label locations as having a result or not (which in the default case is having an anchorage or not). After you get a few of these trained, you can download the human classification results and use them to train a model (see Teachable Machine below).

I wrote a [LinkedIn post](https://www.linkedin.com/posts/c-mcneil_over-the-holidays-i-built-a-rails-app-that-activity-7282081370506461184-zU_S) about the background and motivation for making this.

You'll need a Google Maps API key to get this running locally, and you'll need to enable billing to access the Static Maps API that this uses. 
You could train your own model using [Teachable Machine ](https://teachablemachine.withgoogle.com/) and then export the model as Tensorflowjs. This will allow you to cope the resulting model directly into this app for inference.
<img width="1710" alt="Screenshot 2024-12-31 at 1 30 45 PM" src="https://github.com/user-attachments/assets/09e46209-2215-4ad8-8010-51f7cc819814" />
<img width="1709" alt="Screenshot 2024-12-26 at 10 20 33 AM" src="https://github.com/user-attachments/assets/55e4a93d-bcab-42e3-b6d6-9aa14fd40968" />
<img width="1551" alt="Screenshot 2024-12-26 at 10 19 32 AM" src="https://github.com/user-attachments/assets/c5839e61-12a6-4310-abae-40eef6043513" />
<img width="1356" alt="Screenshot 2025-01-02 at 4 20 38 PM" src="https://github.com/user-attachments/assets/7d988488-2c86-4e46-b1bb-0c9feafe245a" />

Feel free/encouraged to reach out if you have questions or want to get this running locally.



