# RAG Comes to the R Tidyverse Shinyapp code

**This repo isn't ready for use yet!**

It's being created to accompany my soon-to-be-publshed InfoWorld article, RAG Comes to the R Tidyverse. The article and code should publish sometime in mid-July. Please make sure to check it out then! I'll link to it here after publication.

This repo contains a Shiny app file, `app.R`. It is for demo purposes to run locally (or deploy to a server where you're willing to pay for all users' API calls).

Important: There is a strange bug on Windows that has nothing to do with the ragnar package. If you run into 
problems, make sure you have the CRAN version of ellmer, not the development version 
(install it with `install_packages("ellmer")` ) _and_ roll back your `httr2` R package version to 
version 1.1.1 if you have the 1.1.2. 

You can instal httr2 1.1.1 specifically with      
`remotes::install_version("httr2", version = "1.1.1", repos = "https://cloud.r-project.org")`

For this app to run on your system, you also need an OpenAI key stored in an `OPENAI_API_KEY` R environment. This is usually as simple as adding `OPENAI_API_KEY='YOUR_API_KEY_HERE'`to an .Renviron file.

Thanks to the Claude Opus LLM for writing most of this Shiny code 😅 and to
Tomasz Kalinowski at Posit for diagnosing the Windows bug.

![_Screenshot of the app with a chatbot on left and table of workshops on the right_](app_screenshot.png)
