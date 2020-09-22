#!/bin/bash

# Your usage of the data returned by the REST service is
# subject to same conditions as laid out on the Ensembl website.
#
# Copyright [2020] EMBL-European Bioinformatics Institute

# documentation about Ensembl schemas can be found at 
# http://www.ensembl.org/info/docs/api/index.html

# set server details
SERVER=mysql-eg-publicsql.ebi.ac.uk
USER=anonymous
PORT=4157

# get Ensembl Plants current release number from FTP server
# Note: wget is used, this can be modified to use alternatives ie curl
FTPSERVER="ftp://ftp.ensemblgenomes.org/pub"
DIV=plants
SUMFILE="${FTPSERVER}/${DIV}/current/summary.txt"
RELEASE=`wget --quiet -O - $SUMFILE | \
	perl -lne 'if(/Release (\d+) of Ensembl/){ print $1 }'`

# work out Ensembl Genomes release
EGRELEASE=$(( RELEASE - 53));

# alternatively set other EG release number
# EGRELEASE=

echo "EGRELEASE=${EGRELEASE}"
echo

## S1) Check currently supported Ensembl Genomes (EG) core schemas,

# Note: includes non-plants as well

mysql --host $SERVER --user $USER --port $PORT \
	-e "show databases" | grep "core_${EGRELEASE}_${RELEASE}"

# The following API script can also be used:
# https://github.com/Ensembl/ensembl-metadata/blob/master/misc_scripts/get_list_databases_for_division.pl


## S2) Count protein-coding genes of a particular species

SPECIES=arabidopsis_thaliana
SPECIESCORE=$(mysql --host $SERVER --user $USER --port $PORT \
	-e "show databases" | grep "${SPECIES}_core_${EGRELEASE}_${RELEASE}")

mysql --host $SERVER --user $USER --port $PORT \
	$SPECIESCORE -e "SELECT COUNT(*) FROM gene WHERE biotype='protein_coding'"


## S3) Get stable_ids of transcripts used in Compara analyses 

# Canonical transcripts are used in the gene tree analysis,
# which usually are the longest translations with no stop codons.
# This file can be combined to that obtained in recipe F3 to
# obtain the sequences

mysql --host $SERVER --user $USER --port $PORT \
	"ensembl_compara_plants_${EGRELEASE}_${RELEASE}" \
    -e "SELECT sm.stable_id \
		FROM seq_member sm, gene_member gm, genome_db gdb \
		WHERE sm.seq_member_id = gm.canonical_member_id \
		AND sm.genome_db_id = gdb.genome_db_id \
		AND gdb.name = '$SPECIES' \
		LIMIT 10"


## S4) Get variants significantly associated to phenotypes

# Variation schema documented at 
# http://www.ensembl.org/info/docs/api/variation/variation_schema.html

SPECIESVAR=$(mysql --host $SERVER --user $USER --port $PORT \
	-e "show databases" | grep "${SPECIES}_variation_${EGRELEASE}_${RELEASE}")

mysql --host $SERVER --user $USER --port $PORT \
    $SPECIESVAR<<SQL
	SELECT f.object_id, s.name, f.seq_region_start, 
		f.seq_region_end, p.description
    FROM phenotype p 
		JOIN phenotype_feature f ON p.phenotype_id = f.phenotype_id  
		JOIN seq_region s ON f.seq_region_id = s.name
    WHERE f.type = 'Variation' AND f.is_significant=1 LIMIT 10
SQL


## S5) get Triticum aestivum homeologous genes across A,B & D subgenomes

# Compara schema is described at 
# https://m.ensembl.org/info/docs/api/compara/compara_schema.html

# find out the correct method_link_species_set_id in this release
mysql --host $SERVER --user $USER --port $PORT \

	ensembl_compara_plants_${EGRELEASE}_$RELEASE <<SQL
SELECT method_link_species_set_id
FROM method_link_species_set
WHERE name LIKE 'T%aes%homoeologues'
SQL

# update the method_link_species_set_id filter according to the value retrieved above
# remove LIMIT 10 if you want the complete set
mysql --host $SERVER --user $USER --port $PORT \
    ensembl_compara_plants_${EGRELEASE}_$RELEASE <<SQL
SELECT 
	homology_member.homology_id, cigar_line, perc_cov, perc_id, 
	perc_pos, gene_member.stable_id as genes, gene_member.genome_db_id
FROM
	homology_member 
	INNER JOIN homology USING (homology_id)
	INNER JOIN gene_member USING (gene_member_id)
WHERE method_link_species_set_id = 301014
LIMIT 10
SQL
