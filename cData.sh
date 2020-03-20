#!/bin/bash

date=01-22-2020			# start/currentlyProcessed date (MM-DD-YYYY)
stop=$(date +%m-%d-%Y)	# stop collecting data yesterfay (see the loop)

db_file="covid19.db"	# DB file name
db_tmp_t="_test"		# temp CSV import table
db_l_t="_location"		# countries & region table
db_d_t="_data"			# data table

# CSV data source
src="https://nssac.bii.virginia.edu/covid-19/dashboard/data/nssac-ncov-sd-XX-XX-XXXX.csv"

mode="csv"
countryID=""

function usage () {
	cat<<EOF
Usage: ./cData.sh [option(s)]
           (default behaviour - just update local DB)

Options:
  -l       list of all locations
  -c       show data for location
           [58,54,,...]
  -m       output data format
           [csv,column,html,insert,line,list,tabs,tcl]
           (default:CSV)
  -h       help
EOF
}
function helpme () {
	cat<<EOF

This script pulls COVID19 data from nssac.bii.virginia.edu into local SqLite DB.
It has been written and tested for macOS Bash.

Before executing for the first time make sure executable rights are set on the file.

  $ chmod u+x cData.sh
  
First run:

  $ ./cData.sh

Script updates its DB only with new record. It checks the existence of old data
for a location for the specific timestamp.

Just delete local CSV or DB files. Next run will recreate required resources.

EXAMPLES:
=========

  $ ./cData.sh -l
  ---------------
  
  id,city,region
  ...
  38,France,France
  ...
  54,Italy,Italy
  ...
  58,"United Kingdom","United Kingdom"
  206,Uruguay,Uruguay
  237,Uzbekistan,Uzbekistan
  147,"Vatican City","Vatican City"
  207,Venezuela,Venezuela
  34,Vietnam,Vietnam

  
  $ ./cData.sh -c 128 
  -------------------
  
  l_key,ts,confirmed,deaths,recovered
  128,"2020-03-04 08:00:00",1,0,0
  128,"2020-03-06 18:30:00",5,0,0
  128,"2020-03-08 20:00:00",8,0,0
  ...

  ./cData.sh -c 128 -m column
  ---------------------------
  
  l_key       ts                   confirmed   deaths      recovered 
  ----------  -------------------  ----------  ----------  ----------
  128         2020-03-04 08:00:00  1           0           0         
  128         2020-03-06 18:30:00  5           0           0         
  128         2020-03-08 20:00:00  8           0           0         
  ...  
  
TECHNICAL SPECIFICATION:
========================

TABLE _location(
	"id" INTEGER PRIMARY KEY,
	"city" TEXT,
	"region" TEXT
);

TABLE _data(
	"l_key" INTEGER,
	"ts" TEXT,
	"confirmed" INTEGER,
	"deaths" INTEGER,
	"recovered" INTEGER,
	FOREIGN KEY(l_key) REFERENCES _location(id)
);

EOF
}

function db_init(){
	sqlite3 "$db_file" 'CREATE TABLE IF NOT EXISTS '"$db_l_t"'(
		"id" INTEGER PRIMARY KEY,
		"city" TEXT,
		"region" TEXT
	);
	CREATE TABLE IF NOT EXISTS '"$db_d_t"'(
		"l_key" INTEGER,
		"ts" TEXT,
		"confirmed" INTEGER,
		"deaths" INTEGER,
		"recovered" INTEGER,
		FOREIGN KEY(l_key) REFERENCES '"$db_l_t"'(id)
	);'
}

function db_insert(){
	csv_file=${1:?"db_insert: Missing operand #1"}

	go='INSERT INTO '$db_l_t'(city,region)
			SELECT name,Region
			FROM '$db_tmp_t'
			WHERE NOT EXISTS
				(SELECT 1 FROM '$db_l_t' WHERE city = '$db_tmp_t'.name AND region = '$db_tmp_t'.Region);
	INSERT INTO '$db_d_t'(l_key,ts,confirmed,deaths,recovered)
			SELECT id,substr("Last Update",0,20) AS lu,Confirmed,Deaths,Recovered
			FROM '$db_tmp_t' LEFT JOIN '$db_l_t' ON '$db_l_t'.city = '$db_tmp_t'.name AND '$db_l_t'.region = '$db_tmp_t'.Region
			WHERE NOT EXISTS
				(SELECT 1 FROM '$db_d_t' WHERE '$db_d_t'.ts = lu AND '$db_d_t'.l_key = id);'
	
	# DROP temp TABLE
	# import CSV into tmp TABLE
	# update _location & _data from temp
	# DROP temp TABLE
	
	echo -e "DROP TABLE IF EXISTS $db_tmp_t;\n.mode csv\n.import '$csv_file' $db_tmp_t\n$go" | sqlite3 "$db_file"
}

function main(){
	# check is sqlite3 is installed
	if ! [ -x "$(command -v sqlite3)" ]; then
		brew install sqlite3
	fi
	
	# create DB file IF NOT EXISTS
	if [ ! -f "$db_file" ]; then
		touch "db_file"
	fi
	
	# initialise tables IF NOT EXIST
	db_init
	
	while [ "$date" != "$stop" ]; do
		# show processed date without going to a new line each time
		echo -ne "\r\033[0K${date}"
		
		# substitute url with currently processed date
		srcURL="${src/XX-XX-XXXX/$date}"
		
		# save to destination file name
		dstFile="${srcURL##*/}"
		
		# download CSV if local copy doesn't exist
		if [ ! -f "$dstFile" ]; then
			curl -s "${srcURL}" > "$dstFile"
		fi
		
		# update DB
		db_insert "$dstFile"
		
		# step +1 day
		date=$(date -v +1d -jf %m-%d-%Y $date +%m-%d-%Y)
	done
	
	# new line
	echo ""
}

function getCountry(){
	countryID=${1:?"getCountry: Missing operand #1"}
	
	echo -e ".mode $mode\n.h on\nSELECT * FROM _data WHERE l_key = $countryID ORDER BY ts;" | sqlite3 "$db_file"
}

function indexCountry(){
	# create DB file IF NOT EXISTS
	if [ ! -f "$db_file" ]; then
		touch "db_file"
	fi
	# initialise tables IF NOT EXIST
	db_init
	
	echo -e ".mode $mode\n.h on\nSELECT * FROM _location ORDER BY region,city;" | sqlite3 "$db_file"
}

# default function to run
call_func=main

while [[ $# -gt 0 ]];do
	key="$1"
	case $key in
		-l)
		call_func=indexCountry
		shift
		;;
		-c)
		countryID="$2"
		call_func=getCountry
		shift
		shift
		;;
		-m)
		mode="$2"
		shift
		shift
		;;
		-h)
		usage
		helpme
		exit
		;;
		*)    # unknown option
		#POSITIONAL+=("$1") # save it in an array for later
		echo "Unknown option: $1"
		shift # past argument
		usage
		exit 1
		;;
	esac
done

# Tests for required parameters

function test_countryID {
	pass=true
	if [ "$countryID" = "" ]; then
		echo -e "\n-d  ('countryID' parameter required)";
		pass=false
	fi
	
	# Do we have all the parameters?
	if [ "$pass" = false ]; then
		echo ""
		usage
		exit 1
	fi
}

function test_mode {
	pass=false
	if [ "$mode" = "" ]; then
		echo -e "\n-d  ('mode' parameter required)";
		pass=false
	fi
	# csv,column,html,insert,line,list,tabs,tcl
	if [ "$pass" = false ] && [ "$mode" = "csv" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "column" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "html" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "insert" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "line" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "list" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "tabs" ]; then
		pass=true
	fi
	if [ "$pass" = false ] && [ "$mode" = "tlc" ]; then
		pass=true
	fi
	
	# Do we have all the parameters?
	if [ "$pass" = false ]; then
		echo ""
		usage
		exit 1
	fi
}



# Do parameter checks

if [ "$call_func" = getCountry ]; then
	test_countryID;
fi
if [ "$mode" != "csv" ]; then
	test_mode;
fi

# Execute selected function
$call_func "$countryID"

