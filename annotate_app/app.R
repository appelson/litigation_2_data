library(shiny)
library(jsonlite)

agency_categories <- c(
  "Police Department", "Sheriff's Office", "State Police / Highway Patrol",
  "Marshal's Office", "Constable's Office", "Department of Corrections",
  "Jail", "Prison", "Detention Center", "Probation Department",
  "Parole Department", "Campus Police", "Transit Police", "Port Authority Police",
  "Airport Police", "School District Police", "Tribal Police",
  "Drug Enforcement Agency", "Federal Law Enforcement", "Municipality", "Other"
)

race_options <- c(
  "American Indian or Alaska Native", "Asian", "Black or African American",
  "Hispanic or Latino", "Middle Eastern or North African",
  "Native Hawaiian or Other Pacific Islander", "White", "Multiracial", "Other"
)

gender_options <- c(
  "Male", "Female", "Transgender Man", "Transgender Woman", "Nonbinary", "Other"
)

misconduct_options <- c(
  "excessive force", "negligence", "unlawful arrest", "unlawful search", "unlawful stop",
  "unlawful detention", "failure to intervene", "failure to provide medical care",
  "inhumane conditions of confinement", "retaliation", "discrimination",
  "racial profiling", "verbal harassment", "property destruction",
  "fabrication of evidence", "malicious prosecution", "unlawful weapon use",
  "sexual harassment", "sexual assault", "defamation", "police killing", "battery",
  "intentional infliction of emotional distress", "other"
)

location_options <- c(
  "street", "highway", "sidewalk", "home", "apartment", "school",
  "business", "parking lot", "public park", "jail", "prison",
  "police station", "hospital", "vehicle", "court", "university", "other"
)

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: linear-gradient(135deg,#f5f7fa 0%,#c3cfe2 100%); font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif; min-height:100vh; }
      .container-fluid { max-width:1400px; margin:0 auto; padding:30px 20px; }
      .title-panel { background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); color:white; padding:25px 30px; border-radius:12px; margin-bottom:30px; box-shadow:0 8px 16px rgba(0,0,0,0.15); font-weight:600; font-size:2em; text-align:center; }
      .section-header { background:linear-gradient(135deg,#fff 0%,#f8f9fa 100%); padding:15px 20px; margin-top:25px; margin-bottom:20px; border-radius:8px; border-left:5px solid #667eea; font-weight:600; font-size:1.15em; color:#2d3748; box-shadow:0 2px 8px rgba(0,0,0,0.08); }
      .main-panel-content, .file-id-section, .json-preview-container { background:white; padding:25px; border-radius:12px; box-shadow:0 4px 12px rgba(0,0,0,0.1); margin-bottom:20px; }
      .input-section { background:#f8f9fa; padding:20px; border-radius:8px; margin-bottom:15px; border:2px solid #e2e8f0; }
      .added-items { background:white; padding:15px; border-radius:8px; margin-top:15px; border:2px solid #e2e8f0; max-height:300px; overflow-y:auto; }
      .checkbox-group { max-height:220px; overflow-y:auto; border:2px solid #e2e8f0; padding:15px; background:#fafbfc; border-radius:8px; margin-bottom:15px; }
      h5 { color:#2d3748; font-weight:600; margin-top:20px; margin-bottom:15px; padding-bottom:8px; border-bottom:2px solid #e2e8f0; }
      .form-control, .form-select { border:2px solid #e2e8f0; border-radius:6px; padding:10px 12px; transition:.2s; }
      .btn { border-radius:6px; font-weight:600; transition:.2s; border:none; }
      .btn-outline-primary { border:2px solid #667eea; color:#667eea; background:white; }
      .btn-outline-primary:hover { background:#667eea; color:white; transform:translateY(-1px); box-shadow:0 4px 8px rgba(102,126,234,0.3); }
      .btn-success { background:linear-gradient(135deg,#48bb78 0%,#38a169 100%); color:white; }
      .btn-warning { background:linear-gradient(135deg,#ed8936 0%,#dd6b20 100%); color:white; }
      pre { background:#1a202c; color:#68d391; border-radius:8px; padding:20px; overflow-x:auto; max-height:450px; font-family:'Courier New',monospace; border:2px solid #2d3748; line-height:1.6; }
    "))
  ),
  div(class="container-fluid",
      div(class="title-panel","Section 1983 Complaint Data Extractor"),
      
      fluidRow(
        column(12,
               div(class="file-id-section",
                   div(class="section-header","Document Identification"),
                   textInput("case_id","Target File ID / Name","",width="100%"),
                   selectInput("is_complaint","Is this a legal complaint?",choices=c("","TRUE","FALSE"),width="100%")
               )
        )
      ),
      
      fluidRow(
        column(6,
               div(class="main-panel-content",
                   div(class="section-header","1. Law Enforcement Agencies & Officers"),
                   h5("Agencies Mentioned"),
                   div(class="input-section",
                       textInput("agency_name","Agency Name","",width="100%"),
                       selectInput("agency_category","Category",choices=c("",agency_categories),width="100%"),
                       actionButton("add_agency","Add Agency",class="btn-outline-primary btn-sm")
                   ),
                   div(class="added-items",tableOutput("agencies_table")),
                   
                   h5("Individual Officers"),
                   div(class="input-section",
                       textInput("officer_name","Officer Name","",width="100%"),
                       textInput("officer_affiliation","Agency Affiliation","",width="100%"),
                       actionButton("add_officer","Add Officer",class="btn-outline-primary btn-sm")
                   ),
                   div(class="added-items",tableOutput("officers_table")),
                   
                   div(class="section-header","2. Causes of Action"),
                   div(class="input-section",
                       textInput("cause_cited","Cause Cited","",width="100%"),
                       textInput("cause_number","Cause Number","",width="100%"),
                       textInput("cause_defendants","Defendants (semicolon-separated)","",width="100%"),
                       actionButton("add_cause","Add Cause of Action",class="btn-outline-primary btn-sm")
                   ),
                   div(class="added-items",tableOutput("causes_table"))
               )
        ),
        
        column(6,
               div(class="main-panel-content",
                   div(class="section-header","3. Plaintiffs"),
                   h5("Plaintiffs Named"),
                   div(class="input-section",
                       textInput("plaintiff_name","Plaintiff Name","",width="100%"),
                       div(class="checkbox-group",
                           checkboxGroupInput("plaintiff_race","Race",choices=race_options)
                       ),
                       div(class="checkbox-group",
                           checkboxGroupInput("plaintiff_gender","Gender",choices=gender_options)
                       ),
                       actionButton("add_plaintiff","Add Plaintiff",class="btn-outline-primary btn-sm")
                   ),
                   div(class="added-items",tableOutput("plaintiffs_table")),
                   
                   div(class="section-header","4. Incident Details"),
                   
                   h5("Types of Misconduct"),
                   div(class="checkbox-group",
                       checkboxGroupInput("types_misconduct",NULL,choices=misconduct_options)
                   ),
                   
                   h5("Incident Location"),
                   div(class="checkbox-group",
                       checkboxGroupInput("incident_location",NULL,choices=location_options)
                   ),
                   
                   div(class="action-buttons",
                       downloadButton("download_json","Generate & Download JSON",class="btn-success btn-lg"),
                       actionButton("clear_all","Clear Form",class="btn-warning btn-lg")
                   )
               )
        )
      ),
      
      fluidRow(
        column(12,
               div(class="json-preview-container",
                   div(class="section-header","Last Generated JSON (Preview)"),
                   verbatimTextOutput("json_preview")
               )
        )
      )
  )
)

server <- function(input, output, session) {
  
  agencies <- reactiveVal(data.frame(agency_name=character(),agency_category=character(),stringsAsFactors=FALSE))
  officers <- reactiveVal(data.frame(officer_name=character(),agency_affiliation=character(),stringsAsFactors=FALSE))
  plaintiffs <- reactiveVal(data.frame(plaintiff_name=character(),plaintiff_race=character(),plaintiff_gender=character(),stringsAsFactors=FALSE))
  causes <- reactiveVal(data.frame(cause_cited=character(),cause_number=character(),defendants_named=character(),stringsAsFactors=FALSE))
  
  observeEvent(input$add_agency,{
    agencies(rbind(agencies(),data.frame(
      agency_name=ifelse(nzchar(input$agency_name),input$agency_name,""),
      agency_category=ifelse(nzchar(input$agency_category),input$agency_category,""),
      stringsAsFactors=FALSE)))
    updateTextInput(session,"agency_name",value="")
    updateSelectInput(session,"agency_category",selected="")
  })
  
  observeEvent(input$add_officer,{
    officers(rbind(officers(),data.frame(
      officer_name=ifelse(nzchar(input$officer_name),input$officer_name,""),
      agency_affiliation=ifelse(nzchar(input$officer_affiliation),input$officer_affiliation,""),
      stringsAsFactors=FALSE)))
    updateTextInput(session,"officer_name",value="")
    updateTextInput(session,"officer_affiliation",value="")
  })
  
  observeEvent(input$add_plaintiff,{
    plaintiffs(rbind(plaintiffs(),data.frame(
      plaintiff_name=ifelse(nzchar(input$plaintiff_name),input$plaintiff_name,""),
      plaintiff_race=paste(input$plaintiff_race,collapse="; "),
      plaintiff_gender=paste(input$plaintiff_gender,collapse="; "),
      stringsAsFactors=FALSE)))
    updateTextInput(session,"plaintiff_name",value="")
    updateCheckboxGroupInput(session,"plaintiff_race",selected=character())
    updateCheckboxGroupInput(session,"plaintiff_gender",selected=character())
  })
  
  observeEvent(input$add_cause,{
    causes(rbind(causes(),data.frame(
      cause_cited=ifelse(nzchar(input$cause_cited),input$cause_cited,""),
      cause_number=ifelse(nzchar(input$cause_number),input$cause_number,""),
      defendants_named=ifelse(nzchar(input$cause_defendants),input$cause_defendants,""),
      stringsAsFactors=FALSE)))
    updateTextInput(session,"cause_cited",value="")
    updateTextInput(session,"cause_number",value="")
    updateTextInput(session,"cause_defendants",value="")
  })
  
  observeEvent(input$clear_all,{
    agencies(data.frame(agency_name=character(),agency_category=character(),stringsAsFactors=FALSE))
    officers(data.frame(officer_name=character(),agency_affiliation=character(),stringsAsFactors=FALSE))
    plaintiffs(data.frame(plaintiff_name=character(),plaintiff_race=character(),plaintiff_gender=character(),stringsAsFactors=FALSE))
    causes(data.frame(cause_cited=character(),cause_number=character(),defendants_named=character(),stringsAsFactors=FALSE))
    updateTextInput(session,"case_id",value="")
    updateSelectInput(session,"is_complaint",selected="")
    updateCheckboxGroupInput(session,"types_misconduct",selected=character())
    updateCheckboxGroupInput(session,"incident_location",selected=character())
  })
  
  output$agencies_table <- renderTable({ if(nrow(agencies())==0) data.frame(Info="No agencies added yet") else agencies() })
  output$officers_table <- renderTable({ if(nrow(officers())==0) data.frame(Info="No officers added yet") else officers() })
  output$plaintiffs_table <- renderTable({ if(nrow(plaintiffs())==0) data.frame(Info="No plaintiffs added yet") else plaintiffs() })
  output$causes_table <- renderTable({ if(nrow(causes())==0) data.frame(Info="No causes added yet") else causes() })
  
  generate_json <- reactive({
    list(
      is_complaint = ifelse(nzchar(input$is_complaint),input$is_complaint,""),
      agencies = lapply(seq_len(nrow(agencies())),\(i) as.list(agencies()[i,])),
      officers = lapply(seq_len(nrow(officers())),\(i) as.list(officers()[i,])),
      plaintiffs = lapply(seq_len(nrow(plaintiffs())),\(i) as.list(plaintiffs()[i,])),
      causes_of_action = lapply(seq_len(nrow(causes())),\(i) as.list(causes()[i,])),
      types_of_misconduct = ifelse(length(input$types_misconduct)>0,paste(input$types_misconduct,collapse="; "),""),
      incident_location = ifelse(length(input$incident_location)>0,paste(input$incident_location,collapse="; "),"")
    ) |> toJSON(pretty=TRUE,auto_unbox=TRUE)
  })
  
  output$json_preview <- renderText(generate_json())
  
  output$download_json <- downloadHandler(
    filename=function(){
      id <- input$case_id
      if(!nzchar(id)) id <- "extraction"
      paste0(gsub("[^A-Za-z0-9_.-]","_",id),"_",Sys.Date(),".txt")
    },
    content=function(file) writeLines(generate_json(),file)
  )
}

shinyApp(ui,server)
