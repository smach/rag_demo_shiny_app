# RAG Comes to the R Tidyverse Shinyapp code

This repo is to accompany my InfoWorld article RAG Comes to the R Tidyverse scheduled to publish July 17, 2025. If it's July 17 and I haven't included the article link yet, please look for it on the [InfoWorld home page](https://www.infoworld.com) and thank you!!

This repo contains a Shiny app file, `app.R`. It is for demo purposes to run locally (or deploy to a server where you're willing to pay for all users' API calls).

For this app to run on your system, you also need an OpenAI key stored in an `OPENAI_API_KEY` R environment. This is usually as simple as adding `OPENAI_API_KEY='YOUR_API_KEY_HERE'`to an .Renviron file.

I published [a similar app on Posit Connect Cloud that you can check out](https://smach-rag-4-ukraine-workshops-demo-app.share.connect.posit.cloud/). It requires you to input your own OpenAI key as I didn't want to pay for everyone's usage 😅 If you don't have a key, you can still see what it looks like and use the searchable table on the right.

Important: There was a strange bug recently when trying to run the app on Windows that has nothing to do with the ragnar package. If you run into 
problems, make sure you have the development version of ellmer, not the CRAN version 
(install it with `pak::pak(("tidyverse/ellmer")` ). If you want the CRAN version of ellmer, you can deal with the bug by rolling back your `httr2` R package version to 
version 1.1.1 if you have the 1.1.2. 

You can instal httr2 1.1.1 specifically with      
`remotes::install_version("httr2", version = "1.1.1", repos = "https://cloud.r-project.org")`

Thanks to the Claude Opus LLM for writing most of this Shiny code 😅 and to
Tomasz Kalinowski at Posit for diagnosing the Windows bug - and of course for the ragnar package.

![_Screenshot of the app with a chatbot on left and table of workshops on the right_](app_screenshot.png)
