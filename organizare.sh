#!/bin/bash

DOWNLOADS_DIR="Downloads"
MEDIA_DIR="Media"

API_KEY="6c767dfb"


pregatire_nume_film() {
	local nume="$1"
	
	#stergere punct si underscore
	local clean=$(echo "$nume" | tr '._' '  ')

	#ramane doar numele, fara ani, rezolutii, formate etc
	clean=$(echo "$clean" | sed -E 's/([0-9]{4}|1080p|720p|2160p|4k|bluray|brrip|web-dl|hdtv|x264|x265|hevc|yts).*/ /I')
    
	#elimin spatii si paranteze
	clean=$(echo "$clean" | tr -d '[]()' | xargs)
    
	echo "$clean"
}


proceseaza_film() {
	local file="$1"
	local filename=$(basename "$file")
	   	 
	#xtensia fisierului original
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]')
    
	local nume_fara_extensie=$(echo "$filename" | rev | cut -d'.' -f2- | rev)
	local nume_curat=$(pregatire_nume_film "$nume_fara_extensie")
    
	echo "debug intergoare API $nume_curat"
    
	#trimit cerere api, primesc json
	local raspuns_json=$(curl -s "http://www.omdbapi.com/?apikey=${API_KEY}&t=$(echo "$nume_curat" | jq -sRr @uri)")
    
	# verific daca filmul a fost gasit
	local status=$(echo "$raspuns_json" | jq -r '.Response')
    
	if [ "$status" = "True" ]; then
		local titlu_oficial=$(echo "$raspuns_json" | jq -r '.Title')
		local an=$(echo "$raspuns_json" | jq -r '.Year')
		local genuri=$(echo "$raspuns_json" | jq -r '.Genre')
        
		#doar primul gen pentru incadrare
		local gen_principal=$(echo "$genuri" | cut -d',' -f1 | xargs)
		local dest_dir="$MEDIA_DIR/Movies/$gen_principal"
		mkdir -p "$dest_dir"
        
		#"Titlu (An).extensie"
		local noul_nume="${titlu_oficial} (${an}).${extensie}"
        
		echo "gasit: $titlu_oficial ($an) | Gen principal: $gen_principal"
		echo "mutare in: $dest_dir/$noul_nume"
        
		mv "$file" "$dest_dir/$noul_nume"
        
	else
    
		echo "!!! filmul '$nume_curat' nu a fost gasit"
		
		local dest_dir_necunoscut="$MEDIA_DIR/Movies/Uncategorized"
		mkdir -p "$dest_dir_necunoscut"
		mv "$file" "$dest_dir_necunoscut/"
		
	fi
}


proceseaza_serial() {
	local file="$1"
#	echo "debug serial $file"
}


proceseaza_muzica() {
	local file="$1"
#	echo "debug muzica $file"
}


proceseaza_restul() {
	local file="$1"
	local filename=$(basename "$file") #doare nume, fara cale absoluta
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]') #extensia cu litere mici

	if [ -x "$file" ]; #verific executabil
		then

		mv "$file" "$MEDIA_DIR/Executables/"
#		echo "debug executabil $filename"

		return
	fi

#verific document sau alte executabile
	case "$extensie" in
	
		pdf|odt|doc|docx|xls|xlsx|txt|epub)  # !!! adaug extensii pe parcurs daca e necesar !!!
			mv "$file" "$MEDIA_DIR/Documents/"
#			echo "debug document $filename"
		;;

		exe|msi|deb|dmg|sh)
			mv "$file" "$MEDIA_DIR/Executables/"
#			echo "debug executabil (fara drept de executie) $filename"
		;;

		*)
#			echo "debug extensie necunoscuta $filename"
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

