#!/bin/bash

DOWNLOADS_DIR="Downloads"
MEDIA_DIR="Media"






proceseaza_film() {
	local file="$1"
	echo "debug film $file"
}




proceseaza_serial() {
	local file="$1"
	echo "debug serial $file"
}

proceseaza_muzica() {
	local file="$1"
	echo "debug muzica $file"
}




proceseaza_restul() {
	local file="$1"
	local filename=$(basename "$file") #doare nume, fara cale absoluta
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]') #extensia cu litere mici

	if [ -x "$file" ]; #verificam executabil
		then

		mv "$file" "$MEDIA_DIR/Executables/"
		echo "debug executabil $filename"

		return
	fi

#verificam document sau alte executabile
	case "$extensie" in 

		pdf|odt|doc|docx|xls|xlsx|txt|epub)  # !!! adaug extensii pe parcurs daca e necesar !!!
			mv "$file" "$MEDIA_DIR/Documents/"
			echo "debug document $filename"
		;;

		exe|msi|deb|dmg|sh)
			mv "$file" "$MEDIA_DIR/Executables/"
			echo "debug executabil (fara drept de executie) $filename"
		;;

		*)
			echo "debug extensie necunoscuta $filename"
		;;
		
    esac
}

echo "start organizare"

find "$DOWNLOADS_DIR" -type f | while read -r file; do
    
	#unde se afla fisierul
	parent_dir=$(basename "$(dirname "$file")")
    
	case "$parent_dir" in
	
		"Movies")
			proceseaza_film "$file"
			;;
			
		"Series")
            proceseaza_serial "$file"
            ;;

		"Music")
			proceseaza_muzica "$file"
			;;

		"Downloads")
			proceseaza_restul "$file"
			;;
	esac
done

echo "final organizare"

