#!/bin/bash
#variables_start
    #path to project root dir
    rPath=$(realpath "$(dirname "${0:-$0}")")
    currenttime=$(date +"TIME %H:%M:%S:%3N ----")
    currentday=$(date +"DATE %d-%m-%Y")
    headTime=$(date +"TIME %H:%M:%S")
    EVENTS="$rPath/assets/events.txt"
    htmlDoc_Root="/var/www/html/gloriouservices"
    index="$htmlDoc_Root/index.html"
    cssfile="$htmlDoc_Root/main.css"
    ERROR="$rPath/assets/error.txt"
    domain="gloriouservices"
    assets="$rPath/assets"
    places="$htmlDoc_Root/extracted_content.txt"
    SH_PLACES="$htmlDoc_Root/places.sh"
    #Setting variable for domain extention
    domExt=".local"
    #setting full url
    URL="$domain$domExt"
    #setting path to sites-available
    avail="/etc/apache2/sites-available"
    #variable for conf file
    confFile="$avail/$domain.conf"
    hostInput="127.0.0.1 $URL"
    hPATH="/etc/hosts"
    confInput="<VirtualHost *:80>
    ServerAdmin 10037@student-10037
    ServerName $URL
    ServerAlias www.$URL
    DocumentRoot $htmlDoc_Root
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    <Directory $htmlDoc_Root>
    Options +ExecCGI
    AddHandler cgi-script .sh
    AllowOverride All
    </Directory>
    </VirtualHost>"
    NEW_DEPLOY="$rPath/temp_deploy.sh"
#Below variables will be send to other files to be used there. list with variables is long....
CGI="function cgi_page(){"
NOTFOUND="
    municipality=\$(echo \"\$QUERY_STRING\" | sed -n 's/^.*municipality=\\([^&]*\\).*$/\\1/p')

    if ! grep -q \"^\$municipality|^\" \"\$places\"; then
        echo \"Status: 404 Not Found\"
        echo \"Content-type: text/html\"
        echo \"\"
        MAIN_CONTENT=\"<p style='font-size:50pt;'>Error 404. Page not found</p>\"
        exit 1
    fi"

SEND_MAIN="MAIN_CONTENT=\$(awk -F '\\\\|\\\\^\\\\|' -v mun=\"\$municipality\" '\$1 == mun {print \"<p style=\\\"flex:1 0 90%; font-size:35;\\\">Weather forecast for <strong>\" \$1 \",</strong> at \" \$5 \" is: Temperature <strong>\" \$7 \"</strong>, Humidity <strong>\" \$8 \"</strong>, and precipitation <strong>\" \$9 \"</strong>. Last update was <strong>\" \$6 \"</strong>.</p>\"}' \"\$places\")"
HTML_BOIL='

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>gloriouservices</title>
<link rel="stylesheet" href="main.css" />
<style>
main{
  grid-column:1 / 3;
}
</style>
</head>
<body>
<header>
      <ul>
      <li>Webpage completed at:</li>
      <li>'"$headTime"'</li>
      <li>'"$currentday"'</li>
      </ul>
      <h1>Gloriouservices</h1>
      <ul>
      <li>Contact at:</li>
      <li><a href="mailto:10037h@exam.submission">10037 Email</a></li>
      <li>Thank you for visiting!</li>
      </ul>
</header>
<main>
'"$MAIN_CONTENT"'
</main>
<footer>
<ul>
    <li>Webpage created by</li>
    <li>10037</li>
    <li>Copyright: 10037</li>
  </ul>
  <ul>
    <li>Organization number:</li>
    <li>4437-made-by-10037</li>
    <li>Project for Web fundamentals</li>
  </ul>
  <ul>
    <li>NTNU 2023 exam</li>
    <li>part of IDG1100 subject</li>
    <li>10037</li>
  </ul>
</footer>
</body>
</html>
'

CGI_ECHO="
echo \"Content-type: text/html\"
echo \"\"
echo \"\$HTML_BOIL\"
}"




#will be sent to places.sh in /var/www/html/gloriouservices
SH_PLACE_CONTENT="
function update_weather(){
allData=\"\"
# Variables for dates, time, and establishing allData which will be used for weather extraction
nextDayMidday=\$(date -d \"tomorrow 12:00\" '+%Y-%m-%dT%H:%M:%S') 
lastUpdate=\$(date '+%Y-%m-%dT%H:%M:%S')
while IFS= read -r line; do
    # Extract coordinates
    coord=\$(echo \"\$line\" | awk -F '\\\\|\\\\^\\\\|' '{print \$4}')
    # Extract first 4 columns as first_extract
    first_extract=\$(echo \"\$line\" | awk -F '\\\\|\\\\^\\\\|' '{ print \$1\"|^|\"\$2\"|^|\"\$3\"|^|\"\$4}')
    # Requesting and extracting weather from API
    apiResponse=\$(curl -s -H \"Accept: application/xml\" \
                    -H \"User-Agent: my_weather_assignment_NTNU_student_bash_assignment\" \
                    \"https://api.met.no/weatherapi/locationforecast/2.0/classic?\$coord\" | \
                    grep -A 10 \"\$nextDayMidday\" | \
                    awk -v RS=\"</location>\" '/<temperature/ && /<precipitation/ && /<humidity/ {print}')
    # Filtering out temperature, humidity, and precipitation
    temperature=\$(echo \"\$apiResponse\" | sed -n '/<temperature/,/<\\/temperature>/p' | sed -n 's/.*<temperature.*value=\"\\([^\"]*\\)\".*/\\1/p')
    humidity=\$(echo \"\$apiResponse\" | sed -n '/<humidity/,/<\\/humidity>/p' | sed -n 's/.*<humidity.*value=\"\\([^\"]*\\)\".*/\\1/p')
    precipitation=\$(echo \"\$apiResponse\" | sed -n '/<precipitation/,/<\\/precipitation>/p' | sed -n 's/.*<precipitation.*value=\"\\([^\"]*\\)\".*/\\1/p')
    # Appending the data
    allData+=\"\$first_extract|^|\$nextDayMidday|^|\$lastUpdate|^|\$temperature °C|^|\$humidity %|^|\$precipitation mm\"\$'\n'
done < \"\$places\" && echo \"\$allData\" > \"\$places\"

# Remove a specific line from the file. It caused issues with links due to new line statement while printing content into .txt file
sed -i '357d' \"\$places\"
}

if [ \"\$1\" = \"update_weather\" ]; then
    update_weather
elif [ ! -z \"\$QUERY_STRING\" ]; then
    cgi_page
fi

correctlines=false
while [ \"\$correctlines\" = false ]; do
    if [ \$(wc -l < \"\$places\") -eq 356 ]; then
        correctlines=true
        update_weather
        if ! crontab -l | grep -q \"places.sh update_weather\"; then
            (crontab -l 2>/dev/null; echo \"*/30 * * * * places.sh update_weather\") | crontab -
        fi
    fi
    sleep 5
done

"



deploy_content="
#moves original deploy.sh file into assets and renames it into setup.sh
mv \"\$rPath/deploy.sh\" \"\$rPath/assets/setup.sh\"
echo \"\$currentday \$currenttime Original deploy.sh has been moved to /assets/setup.sh\" >> \"\$EVENTS\" 

#renames temp_deploy.sh into deploy.sh
mv \"\$rPath/temp_deploy.sh\" \"\$rPath/deploy.sh\"
#sends information to events.txt
echo \"\$currentday \$currenttime deploy.sh has finished setting up the dir/file structure and inputted necessary information to files/dirs\" >> \"\$EVENTS\"
echo \"\$currentday \$currenttime New file has been created and named deploy.sh. it will now enable website\" >> \"\$EVENTS\"
echo \"\$currentday \$currenttime If you choose to stop the webpage, and want to start it again, please use sudo deploy.sh\" >> \"\$EVENTS\"

##sets ownership for apache document root
chown www-data:www-data \"\$confFile\"
chown -R www-data:www-data \"\$htmlDoc_Root\"
chmod -R 755 \"\$htmlDoc_Root\"
chmod +x \"\$SH_PLACES\"

echo \"\$currentday \$currenttime Permissions have been set\" >> \"\$EVENTS\"
echo \"\"
echo \"\"
echo \"\"
echo \"Webpage will start as soon as weatherinformation is collected\"
echo \"\"
echo \"\"
echo \"\"
#enables apache2 file and reloads apache2 to have changes take effect. 
#Made it into a loop to not start the webpage before the weather information is collected. 
#and to make sure it keeps loooking untill it can find a value. i set |^|0. because its the separators used before precipitation.
found=0
while [ \$found -eq 0 ]; do
    if grep -q '|^|0.' \"\$places\"; then
        found=1
        a2ensite gloriouservices.conf
        systemctl start apache2
        systemctl restart apache2
        systemctl reload apache2
    fi
    sleep 5
done
echo \"Website is enabled\"
echo \"\$currentday \$currenttime Apache2 has been started\" >> \"\$EVENTS\"
if [ \"\$(wc -l < \"\$ERROR\")\" -gt 1 ]
then echo \"errors detected and logged in \$ERROR\"; else echo \"No errors detected. Errors logged in \"\$ERROR\"\"
fi
if [ -s \"\$EVENTS\" ]
then echo \"Please see events that have been logged in events.txt. Path: \$EVENTS\"
fi
echo \"Use gloriouservices.local to open webpage in web browser\"
echo \"\$currentday \$currenttime Use gloriouservices.local to open webpage in browser. only works for local networks\" >> \"\$EVENTS\"
"
cssCont='body {
        margin: 0;
        padding: 0;
        font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
          Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;
        display: grid;
        grid-template-columns: 1fr 80%;
        grid-template-rows: auto minmax(80vh, auto) minmax(10vh, auto);
        background-color: rgb(246, 246, 246);
      }

      body * {
        box-sizing: border-box;
      }

      header {
        padding: 0px 15px 5px 0px;
        grid-column: 1 / 3;
        grid-row: 1;
        display: grid;
        grid-template-columns: 25% 50% 25%;
        align-items: end;
        min-height: 100px;
        justify-content: center;
        background-color: rgb(114, 114, 226);
        margin-bottom: 15px;
        color: white;
      }

      header > * {
        margin: 0;
        padding: 0;
        height: 100%;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }

      header h1{
        grid-column:2;
      }

      header ul {
        gap: 8px;
        flex-direction: column;
        font-size: 10pt;
        display:flex;
        align-items: center;
        text-align: left;
        padding:0;
      }
      header>ul:first-of-type{
        grid-column:1;
      }
      header>ul:last-of-type{
        grid-column:3;
      }

      header ul li {
        display: inline-block;
      }

      aside {
        grid-column: 1;
        grid-row: 2;
        border-radius: 5px;
        margin-left: 15px;
        padding: 15px;
        overflow:scroll;
        max-height:100vh;
        display:flex;
        flex-direction:column;
        align-items:center;
      }

      aside p {
        z-index: 10;
      }

      aside,
      main {
        background-color: white;
        border:solid white 15px;
      }

      header,
      aside,
      main,
      footer {
        box-shadow: 0px 0px 3px 3px rgba(0, 0, 0, 0.092);
      }

      main {
        margin: 0px 15px 0px 15px;
        border-radius: 5px;
        width: 98%;
        height: auto;
        border-radius: 5px;
        display: flex;
        flex-direction: row;
        flex-wrap: wrap;
        gap: 10px;
        overflow:scroll;
        align-items:center;
        max-height:100vh;
        text-align:center;
        padding:15px;
        font-size: 12pt;
      }

      main p{
        display: flex;
        align-items: center;
        justify-content: center;
        flex: 1 0 48%;
        box-shadow: 0px 0px 2px 2px rgba(0, 0, 0, 0.245);
        margin: 0;
        height: 50px;
        border-radius: 5px;
        transition: 0.1s ease-in-out;
      }

      main a{
        color:black;
        text-decoration:none;
      }

      main h2{
        flex: 1 0 95%;
      }

      aside a{
        box-shadow: 0px 0px 2px 2px rgba(0, 0, 0, 0.245);
        display: flex;
        justify-content: center;
        align-items: center;
        padding: 15px 0px 15px 0px;
        width: 93%;
        height: 50px;
        border-radius: 5px;
        margin: 10px;
        transition: 0.1s ease-in-out;
        text-decoration: none;
        color: rgb(0, 0, 90);
      }

      aside a:hover, main p:hover{
        background: rgb(228, 228, 228);
      }

      footer {
        grid-row: 3;
        grid-column: 1 / 3;
        margin-top: 15px;
        background-color: white;
        display: flex;
        flex-direction: row;
        gap: 20px;
        justify-content: space-evenly;
        align-items: center;
      }

      footer ul {
        padding: 0;
        flex: 1 1 27%;
        display: flex;
        flex-direction: column;
        align-items: center;
      }

      footer li {
        display: inline-block;
      }
      
      main::-webkit-scrollbar, aside::-webkit-scrollbar {
        width: 10px;
        border-radius: 5px;
        }

      main::-webkit-scrollbar-track, aside::-webkit-scrollbar-track {
            background: transparent;
        }

      main::-webkit-scrollbar-thumb, aside::-webkit-scrollbar-thumb {
            background: grey;
            border-radius: 5px;
            height: 60%;
        }

      main::-webkit-scrollbar-horizontal, aside::-webkit-scrollbar-horizontal {
            display: none;
        }'
#variables_end
#if this script is deployed, and then stopped, only to be deployed again, it will stop the last cronjob, in order to not create dup's
function removecrontab(){
    [ -f "$SH_PLACES" ] && crontab -l | grep -q "$SH_PLACES" && \
    (crontab -l | grep -v "$SH_PLACES") | crontab -
    sleep 1
}

function are_you_sure(){
    #if script has already been run, it first removes files from previous
    if [ -d "$assets" ]; then 
    rm -r "$assets" 
    fi
    if [ -f "$NEW_DEPLOY" ]; then
    rm "$NEW_DEPLOY" ; fi
    if [ -d "$htmlDoc_Root" ]
    then    rm -r "$htmlDoc_Root" 
    fi
    if [ -f "$confFile" ]    
    then rm "$confFile"
    fi
    sleep 1
    

#creating a box around message, both to make it visible and look nice. telling the user what script will do and requirements
for ((i=0; i < 12; i++)); do echo "";done
echo "    ------------------------------------------------------------------------------------------" && echo "    |                                                                                        |" && echo "    |                                     PLEASE NOTE!                                       |" && echo "    |                                                                                        |"
echo "    |    This script builds dir/file structure and start gloriouservices.local.              |" && echo "    |    Make sure you give the script the necessary permissions by running it with sudo.    |" && echo "    |    If you do this, it will make changes to your directory structure.                   |" && echo "    |    deploy.sh HAS TO BE DEPLOYED USING SUDO. Script will restart and reload apache2     |"
echo "    |    apache2 and curl is required for script to function.                                |" && echo "    |    deploy.sh will affect dirs and files:                                               |" && echo "    |    /var/www/html,                                                                      |" && echo "    |    /etc/apache2/sites-available,                                                       |"
echo "    |    /etc/apache2/sites-enabled,                                                         |" && echo "    |    /etc/hosts,                                                                         |" && echo "    |    the current directory you placed deploy.sh inside and file deploy.sh itself         |"
echo "    |                                                                                        |" && echo "    |                         Are you sure you want to continue?[Y/n]                        |" && echo "    |                                                                                        |"&&echo "    ------------------------------------------------------------------------------------------"
for ((i=0; i < 3; i++)); do echo "";done
while true; do
    read -r -p "            "  response
    case $response in
        [Yy]* ) echo "-----------------------------------------" && echo ""&&echo "      Running script"&&echo "      This might take a little while"
        echo "      To view progress, do:"&&echo "      sudo nano $places"&&echo "      To see events, do:"
        echo "      sudo nano $EVENTS"&&echo ""&&echo "-----------------------------------------"; break;;
        [Nn]* ) echo "      Stopping script"; exit 1;; * ) echo "      Invalid reply";;
    esac
done
for ((i=0; i < 5; i++)); do echo "";done
}

#function under is setting up directory and file structure, ontop of inserting content into files
function filemanager(){
    #creates  dirs and files that should be inside them
    mkdir "$assets" && touch "$EVENTS" "$ERROR"
    echo "$currentday $currenttime Starting script" >> "$EVENTS" && echo "$currentday $currenttime If there are any errors. Please make sure that file has not been corrupted since there were no issues when making the script." >> "$ERROR"
    # shellcheck disable=SC2129
    echo -e "$currentday $currenttime Created dir $assets\n$currentday $currenttime Created file $EVENTS\n$currentday $currenttime Created file $ERROR" >> "$EVENTS"
    #created html document root and files to live in it
    mkdir "$htmlDoc_Root" && touch "$index" "$cssfile" "$places" "$SH_PLACES" && echo "$cssCont" >> "$cssfile"
    # shellcheck disable=SC2129
    echo -e "$currentday $currenttime Created dir $htmlDoc_Root\n$currentday $currenttime Created file $index\n$currentday $currenttime Created file $cssfile\n$currentday $currenttime Inserted content to $cssfile\n$currentday $currenttime Created file $places" >> "$EVENTS"
    echo "$currentday $currenttime created $SH_PLACES" >> "$EVENTS"
    #checks that sites-available is present. Creates -conf file if is, tells usier if it is not. created as failsafe
if [ ! -d "$avail" ]; then for ((i=0; i < 5; i++)); do echo ""; done &&echo ""&& echo "      ERROR!" && echo "$avail not found. Dir is necessary. Running without might cause issues. Do you still want to continue?[Y/n]" 
  echo "$currentday $currenttime Cannot find $avail" >> "$ERROR"; read -r -p "      " response && { [[ $response =~ ^[Yy] ]] && echo "We do not advise this, but script will continue" || { echo "      Stopping script"; exit 1; }; }
  else touch "$confFile" && echo "$confInput" > "$confFile" && echo -e "$currentday $currenttime Created file $confFile\n$currentday $currenttime Inserted content to $confFile" >> "$EVENTS"; 
fi
    #checks that it can find /etc/hosts
if [ -f "$hPATH" ]; then
  #checks if the correct line already exists in hosts, inserts if not present
  if ! grep -q "$hostInput" "$hPATH"; then echo "$hostInput" | tee -a "$hPATH" && echo "$currentday $currenttime $hostInput has been inserted to $hPATH" >> "$EVENTS"
    else for ((i=0; i < 2; i++)); do echo "";done && echo "$currentday $currenttime $hostInput was not inserted into $hPATH since it is already present" >> "$EVENTS"
    echo "$currentday $currenttime Failed to insert $hostInput to $hPATH because line is already present" >> "$ERROR"
  fi else echo "cannot find $hPATH" && echo "$currentday $currenttime Cannot find $hPATH" >> "$ERROR" #if it cannot find hosts file, echoes to terminal
fi    #removes temp_deploy if existing, then creates it again - avoid up files
      if [ -f "$NEW_DEPLOY" ]; then rm "$NEW_DEPLOY"; fi && touch "$NEW_DEPLOY"
#REMOV REMOVE REMOVE REMOVE REMOVE REMOVE REMOVE FILE IS REDUNDANT
}

#function below extracts all necessary content and automatically places it in the desired format in a .txt file with(next line) 
#separators (used this; |^|)so i can design the output to index.html the way i want it
function extraction {
    #if statement checks that extracted.txt does not contain any information: to avoid dup content
    if [ ! -s "$places" ]; then for ((i=0; i < 3; i++)); do echo "";done
    #tells the user to not stop script since extracting takes some time
    echo "EXTRACTING COORDINATES. DO NOT STOP SCRIPT" && echo "You will receive a notice when extraction is complete" && for ((i=0; i < 2; i++)); do echo "";done
    #extracts Wikipedia page and processes it
    curl "https://en.wikipedia.org/wiki/List_of_municipalities_of_Norway" |
    #removes spans, and makes sure it removes all types of spans regardless of variable content. 
    #to make sure its able to read the file correctly and extract the correct table later
    sed 's/<span [^>]*>//'|
    #removes span end tags
    sed 's/<\/span>//'|
    #filters out relevant table
    sed -n '/<table class="sortable wikitable">/,/<\/table>/p' |
    #removes the <th> start and end tag since it is not necessary
    sed '/<th/,/<\/th>/d' |
    #awk goes through the lines and selects the relevant <td> elements
    awk 'BEGIN { in_tr = 0; td_count = 0; line_two = ""; }
/<tr>/ { in_tr = 1; td_count = 0; line_two = ""; }
/<\/tr>/ { in_tr = 0; }
{ 
    if (in_tr) {
        if (/\<td\>/) {
            td_count++;
            gsub(/<td>|<\/td>/, "");
            if (td_count == 2) {
                line_two = $0; 
            } else if (td_count == 5) {
                printf "%s%s\n", line_two, $0;
            }
        }
    }
}' |
    #standarizes the links to make it easier/more practical to use them later and makes a href into actual links
    sed 's|<a href="/\([^"]*\)" [^>]*>\([^<]*\)</a>|<a href="https://en.wikipedia.org/\1">\2</a>|' |
    #removes left over spans
    sed 's|<span [^>]*>.*</span>||g' |
    #removes <br elements. caused issues when it was not removed
    sed 's|<br [^>]*>||g' |
    #curled and refined information from wikipedia is directly piped to loop
    #loop reads the content, splits it into different variables, visits links and extracts coordinates
    #process extracted data
    while IFS= read -r line; do
        #reads first curl output and extracts content beetween a href start tag and end tag. gives it variable name muni_name
        muni_name=$(echo "$line" | sed -n 's/<a href="[^"]*">\([^<]*\)<\/a>.*/\1/p')
        #reads first curl output and extracts content after </a>, e.g: the population number from <td> 5 (5ft <td> inside each <tr>)
        population=$(echo "$line" | sed -n 's/<a href="[^"]*">[^<]*<\/a>\(.*\)/\1/p')
        #reads first curled output, greps out the links inside a href="here" and gives it variable name wikiURL
        #knowlingly not turning "æ, ø, å" into "a, o, a" since its needed for the links to work.
        wikiURL=$(echo "$line" | grep -o 'https://[^"]*')
        #makes content into variable which is curling the links extracted with grep in line above
        content=$(curl -s "$wikiURL")
        #makes coords into variable holding coordinates information
        coords=$(echo "$content" | 
            #visits page and makes spans start on new line to make a structure that can be read easier by sed
            sed 's/<span/\n<span/g' | 
            #makes table to be extracted starts on a new line to make a structure easier for sed to work with
            sed 's/<table class="infobox ib-settlement vcard">/\n<table class="infobox ib-settlement vcard">/g' | 
            #extracts the content of table
            sed -n '/<table class="infobox ib-settlement vcard">/,/<\/table>/p' | 
            #use awk to target the correct spans i want to extract, extracts them and gives them variable names
            awk -v FS="<span class=\"|</span>" '
                /<span class="latitude">/ { lat = $2; next; }
                /<span class="longitude">/ { lon = $2; printf "%s |%s\n", lat, lon; }
            ' | 
            #removes left over latitude and longitude from span class=... Could not be removed earlier, since awk would then not know exactly what spans to extract
            sed -e 's/latitude">//' -e 's/longitude">//' | 
            #makes normal coordinate chars into spaces and removes letters like N S E W to make them easier to calculate
            sed 's/°/ /g; s/′/ /g; s/″/ /g; s/[NSEW]//g' | 
            #convers coordinates from degrees to decimals and gives them variable names
            #printing out the coordinates as lat=number&lon=number because this is the format needed for the api, and will save me extra steps later
            LC_NUMERIC="en_US.UTF-8" awk -F '|' '{
            split($1, lat, " "); 
            split($2, lon, " "); 
            lat_dec = lat[1] + (lat[2] / 60) + (lat[3] / 3600); 
            lon_dec = lon[1] + (lon[2] / 60) + (lon[3] / 3600); 
            printf "lat=%f&lon=%f", lat_dec, lon_dec;
    }')
        #echoes out content of variables into file and adds separators to make it easier to manage later
        #inserts to /var/www/html/gloriouservices/extracted_content.txt since it is needed there to gather weather data. this deploy.sh can collect data from there too
        echo "$muni_name|^|$population|^|$wikiURL|^|$coords" >> "$places"
    done
        echo "" && echo "COORDINATES EXTRACTION COMPLETE"&& echo ""
        echo "Coordinated have been extracted. commencing extracting weather forecast"
        echo "$currentday $currenttime Coordinates have been extracted. commencing forecast extraction" >> "$EVENTS"
        echo "Extracted information sent to:"&& echo "$places" && echo "$currentday $currenttime Extraction complete" >> "$EVENTS"
        sed -i '357d' "$places"
fi }

function web_insert(){
    #makes sure that all content necessary is available and correct before proceeding with inserting to index.html
    #makes sure that extracted.txt eexists, has content and that it has the correct amount of lines (356 lines)
    if [ -f "$places" ] && [ -s "$places" ]
      then
        #extracts the content of extracted.txt, designes sentence and puts it in variable to be inserted to index.html
        extract_to_page=$(awk -F '\\|\\^\\|' 'BEGIN { ORS="" } { print "<p><a href=\"http://gloriouservices.local/places.sh?municipality="$1"\">Weather for "$1". Population "$2". Coordinates: "$4"</a></p>"}' < "$places") 
        #chooses the link from etracted file, puts it in a <a href> and puts the name as the output content. sorts it alphabetically to be used in aside
        aside_cont=$(awk -F '\\|\\^\\|' '{print "<a href=\""$3"\">"$1"</a>"}' < "$places" | sort)
        #variable containing content to be used in footer
        footer_cont='
          <ul>
            <li>Webpage created by</li>
            <li>10037</li>
            <li>Copyright: 10037</li>
          </ul>
          <ul>
            <li>Organization number:</li>
            <li>4437-made-by-10037</li>
            <li>Project for Web fundamentals</li>
          </ul>
          <ul>
            <li>NTNU 2023 exam</li>
            <li>part of IDG1100 subject</li>
            <li>10037</li>
          </ul>'
        #Variable containing content to be used in header
        header_cont='
          <ul>
          <li>Webpage completed at:</li>
          <li>'"$headTime"'</li>
          <li>'"$currentday"'</li>
          </ul>
          <h1>Gloriouservices</h1>
          <ul>
          <li>Contact at:</li>
          <li><a href="mailto:10037h@exam.submission">10037 Email</a>
          <li>Made by 10037!</li>
          </ul>'
          #variable for html content 
        htmlDoc='
          <!DOCTYPE html>
          <html lang="en">
            <head>
              <meta charset="UTF-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1.0" />
              <title>gloriouservices</title>
              <link rel="stylesheet" href="main.css">
            </head>
            <body>
              <header>
                '"$header_cont"'
              </header>
              <aside>
                <h3>Municipalities, alphabetical order</h3>
                  <p>visit munipality wikipedia page</p>
                    '"$aside_cont"'
                  </aside>
                <main> 
                  <h2>Click one for more information</h2>
                  '"$extract_to_page"'
                </main>
                <footer>'"$footer_cont"'</footer>
              </body>
          </html>'
            #inserts contect of html variable into index.html file
        echo "$htmlDoc" > "$index"
        echo "$currentday $currenttime Content inserted to $index" >> "$EVENTS"
      else
        for ((i=0; i < 3; i++)); do echo "";done #if the if statement is false: will tell user that there is an issue and to check
        echo "  ISSUE WHILE IMPORTING CONTENT TO INDEX.HTML"
        echo ""
        echo "  Make sure extracted.txt can be found and has exactly 356 lines"
        echo ""    
    fi }

function new_deploy(){
    #inserts content to newly created .sh files
    sed -n '1,24p' "$rPath/deploy.sh" > "$NEW_DEPLOY" 
    echo "$deploy_content" >> "$NEW_DEPLOY"
    #made sure to insert them to $SH_PLACES in the correct order, since its important in order to build a functional script
    # shellcheck disable=SC2129
    sed -n '1,24p' "$rPath/deploy.sh" >> "$SH_PLACES"
    echo "$FILECHECK" >> "$SH_PLACES"
    echo "$CGI" >> "$SH_PLACES"
    echo "$NOTFOUND" >> "$SH_PLACES"
    echo "$SEND_MAIN" >> "$SH_PLACES"
    sed -n '55,106p' "$rPath/deploy.sh" >> "$SH_PLACES"
    echo "$CGI_ECHO" >> "$SH_PLACES"
    echo "$SH_PLACE_CONTENT" >> "$SH_PLACES"
    #inserts variable holding information to be used in temp_deploy.sh into temp_deploy.sh
    
    #adds to even that temp_deploy.sh has been created
    echo "$currentday $currenttime New deploy file has been created" >> "$EVENTS"
    echo "$currentday $currenttime Content inserted to $SH_PLACES" >> "$EVENTS"
    echo
    #makes sure temp_deploy.sh is executable
    chmod +x "$NEW_DEPLOY"
    chown www-data:www-data "$SH_PLACES"
    chmod +x "$SH_PLACES"
    a2enmod cgid
    #starts running temp_deploy.sh
    $SH_PLACES
    $NEW_DEPLOY
}
removecrontab
are_you_sure
filemanager
extraction
web_insert
new_deploy