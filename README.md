# Snitch

A service to track reports of objectionable content and the corresponding moderator decisions


## Api

Report an object as objectionable. Uses checkpoint to attach a user to the report, but accepts anonymous reports.

    POST /reports/:uid

Return a paginated list of unprocessed reported content that the moderator should respond to. The common pagination 
options apply (`limit`, `offset`).

    GET /items?path=<realm>&limit=<limit>&offset=<offset>
    => {
         "items": [
           {item: 
             {"uid": <uid of reported object>, 
              "report_count": <number of reports> 
              "decision": <moderator decision (always null)>
              "created_at": <time of first report or moderator decision>}
           }, 
         ... (list of items) ],
         "pagination": {
           "limit": <limit>,
           "offset": <offset>,
           "last_page": <more content? true/false>
         }
       }
            
Register a moderator decision:

    POST /items/:uid/decision (post data: {"decision": <a valid decision label>})

Decisions are either 'kept' or 'removed'. Actual removal of content is not performed by snitch, but this will
remove the item from the default list returned by GET /items. Currently the user reporting a decision must 
be god of the given realm, but this is just a temporary solution until we have a proper concept of "moderators".
Both the decision and the decider is registered with the item in question.

Optionally you can provide a "rationale" label to explain the reason for the decision. Defined rationales at this time 
is (provided here with the norwegian translations used in Origo):

    'unspecified' -> Uspesifisert
    'practical' -> Praktiske årsaker
    'relevance' -> Avsporing
    'adhominem' -> Personangrep
    'hatespeech' -> Hat-ytring
    'doublepost' -> Dobbelposting
    'legal' -> Mulig Lovbrudd
    'rules' -> Brudd på medlemsavtalen
    'advertising' -> Snikreklame

Additionally you can provide a "message" which is an explanation of the decision. This should be directed at the
offender as this message in the future may be sent to the original poster.



## Getting Started

    git clone git@github.com:benglerpebbles/snitch.git snitch
    cd snitch

    rake db:bootstrap
