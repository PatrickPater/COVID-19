# COVID-19 data

This script pulls COVID-19 data from [nssac.bii.virginia.edu](https://nssac.bii.virginia.edu) into local SqLite DB. It has been written and tested for macOS Bash.

Before executing for the first time make sure executable rights are set on the file.

	$ chmod u+x cData.sh
  
First run:

	$ ./cData.sh

Script updates its DB only with new records. It checks the existence of old data for a location for the specific timestamp.

Just delete local CSV or DB files. Next run will recreate required resources.


## Usage

	./cData.sh [option(s)]

(default behaviour - just update local DB)

Options:

	-l       list of all locations
	-c       show data for location
	         [58,54,,...]
	-m       output data format
	         [csv,column,html,insert,line,list,tabs,tcl]
	         (default:CSV)
	
	-h       help

## EXAMPLES

	$ ./cData.sh -l
 
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
 
	l_key,ts,confirmed,deaths,recovered
	128,"2020-03-04 08:00:00",1,0,0
	128,"2020-03-06 18:30:00",5,0,0
	128,"2020-03-08 20:00:00",8,0,0
	...
 	
	./cData.sh -c 128 -m column
 
	l_key       ts                   confirmed   deaths      recovered 
	----------  -------------------  ----------  ----------  ----------
	128         2020-03-04 08:00:00  1           0           0         
	128         2020-03-06 18:30:00  5           0           0         
	128         2020-03-08 20:00:00  8           0           0         
	...  
	
## TECHNICAL SPECIFICATION

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
