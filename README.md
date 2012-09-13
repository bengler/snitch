# Snitch

A service to track reports of objectionable content and the corresponding moderator decisions


## Api


### POST /reports/:uid

Report an object as objectionable. Uses checkpoint to attach a user to the report, but accepts anonymous reports.

    POST /reports/:uid

### GET /items/:wildcard_path
Return a paginated list of unprocessed reported content that the moderator should respond to. The common pagination
options apply (`limit`, `offset`).

    GET /items/:wildcard_path&limit=<limit>&offset=<offset>
    => {
         "items": [
           {item:
             {"uid": <uid of reported object>,
              "report_count": <number of reports>,
              "decision": <moderator decision>,
              "decider": <identity id of decider>,
              "action_at": <time of last moderator action on this object>,
              "created_at": <time of first report or moderator decision>}
           },
         ... (list of items) ],
         "pagination": {
           "limit": <limit>,
           "offset": <offset>,
           "last_page": <more content? true/false>
         }
       }

Optionally you can provide a :scope for the request:

    'pending': (default) Any reported items that have no registered decision
    'processed': Items that have been decided upon
    'reported': All reported items, including items that have recieved a decision
    'fresh': Any fresh content that has not been marked as seen by a moderator

### GET /items/uid,uid,uid...
You may also input a list of full UIDs:

    GET /items/a.b.c$1,a.b.c$2,a.b.c$3,
    => {
         "items": [
           {item:
             {"uid": <uid of reported object>,
              "report_count": <number of reports>,
              "decision": <moderator decision>,
              "decider": <identity id of decider>,
              "action_at": <time of last moderator action on this object>,
              "created_at": <time of first report or moderator decision>}
           },
         ... (list of items) ],
         "pagination": {
           "limit": <number_of_hits>,
           "offset": 0,
           "last_page": true
         }
       }

Note: pagination will not be possible with this type of query as it always returns
the exact items and in the exact order as the input uid list.
If an item is not found, it will output a null item in the same position as the input.

### POST /items/:uid
Notify snitch of the existence of an item:

    POST /items/:uid

This is used to notify snitch of the existence of new content. Some moderators like to review new content as it
arrives. Go figure. To let snitch know a moderator has seen an item, post an action of the kind "seen". (Any
other action will also mark the item as seen.)


### POST /items/:uid/actions

Register a moderator decision:

    POST /items/:uid/actions (post data: {"action": {"kind": <a valid decision label>})

Actions are either ```kept```, ```removed```, ```seen``` or ```edited```.

Actual removal of content is not performed by snitch, but this will
remove the item from the default list returned by GET /items. Currently the user reporting a decision must
be god of the given realm, but this is just a temporary solution until we have a proper concept of "moderators".
Both the decision and the decider is registered with the item in question.

Optionally you can provide a "rationale" label to explain the reason for the action. Defined rationales at this time
is (provided here with the norwegian translations used in Origo):

    'practical' -> Praktiske årsaker
    'relevance' -> Avsporing
    'adhominem' -> Personangrep
    'hatespeech' -> Hat-ytring
    'doublepost' -> Dobbelposting
    'legal' -> Mulig Lovbrudd
    'rules' -> Brudd på medlemsavtalen
    'advertising' -> Snikreklame

Additionally you can provide a "message" which is a human readable explanation of the action. This should be directed at the
offender as this message in the future may be provided to the original poster.

### GET /items/:wildcard_uid/actions
Get lists of moderator decisions:

    GET /items/:wildcard_uid/actions&limit=<limit>&offset=<offset>

Returns a paginated list of recent actions on items matching the wildcard uid sorted by date. By default this will only
go as far back as 30 days for performance reasons. By passing a date to the parameter :since you may page even further back.


## Getting Started

    git clone git@github.com:benglerpebbles/snitch.git snitch
    cd snitch

    rake db:bootstrap
