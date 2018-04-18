function GetFinalSheetFolderGlobalPathWithoutNumber(){
    local mode string
    #Since this function can be used, e.g., in exam mode to get the exercise
    #final folder, we cannot here just rely on the EXHND_make* variables
    if [ "$1" != '' ]; then
        mode=$1
        if [[ ! ${mode} =~ ^(EXERCISE|SOLUTION|SOLUTION-EXAM|EXAM|PRESENCE)$ ]]; then
            PrintInternal "Function \"${FUNCNAME[0]}\" called with unexpected second argument (\$2=\"$2\")!"; exit -1
        fi
    else
        if [ ${EXHND_makeExerciseSheet} = 'TRUE' ] || [ ${EXHND_listUsedExercises} = 'TRUE' ]; then
            mode='EXERCISE'
        elif [ ${EXHND_makeSolutionSheet} = 'TRUE' ]; then
            if [ ${EXHND_solutionOfExam} = 'TRUE' ]; then
                mode='SOLUTION-EXAM'
            else
                mode='SOLUTION'
            fi
        elif [ ${EXHND_makeExam} = 'TRUE' ]; then
            mode='EXAM'
        elif [ ${EXHND_makePresenceSheet} = 'TRUE' ]; then
            mode='PRESENCE'
        else
            PrintInternal "Function \"${FUNCNAME[0]}\" called in unexpected scenario!"; exit -1
        fi
    fi
    if [ ${mode} = 'EXERCISE' ]; then
        string="${EXHND_finalExerciseSheetFolder}/${EXHND_finalExerciseSheetPrefix}"
    elif [ ${mode} = 'SOLUTION' ]; then
        string="${EXHND_finalSolutionSheetFolder}/${EXHND_finalSolutionSheetPrefix}"
    elif [ ${mode} = 'SOLUTION-EXAM' ]; then
        string="${EXHND_finalExamSheetFolder}/${EXHND_finalExamSolutionPrefix}"
    elif [ ${mode} = 'EXAM' ]; then
        string="${EXHND_finalExamSheetFolder}/${EXHND_finalExamSheetPrefix}"
    elif [ ${mode} = 'PRESENCE' ]; then
        string="${EXHND_presenceSheetFolder}/${EXHND_presenceSheetPrefix}"
    fi
    echo ${string}
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function __static__DetermineSheetNumber(){
    local lastSheetNumber string finalFoldersArray
    if [ ${EXHND_makeExam} = 'TRUE' ] || { [ ${EXHND_makeSolutionSheet} = 'TRUE' ] && [ ${EXHND_solutionOfExam} = 'TRUE' ] ; }; then
        string=$(GetFinalSheetFolderGlobalPathWithoutNumber 'EXAM')     || exit -1 #https://stackoverflow.com/a/20157997
    else
        string=$(GetFinalSheetFolderGlobalPathWithoutNumber 'EXERCISE') || exit -1 #https://stackoverflow.com/a/20157997
    fi
    finalFoldersArray=( $(ls -d ${string}*/ 2>/dev/null) )
    if [ ${#finalFoldersArray[@]} -eq 0 ]; then
        echo '1'
        return
    fi
    lastSheetNumber=$(grep -o "[0-9]\+" <<< "$(basename ${finalFoldersArray[-1]})")
    if [[ $lastSheetNumber =~ ^[0-9]+$ ]]; then
        lastSheetNumber=$(awk '{print $1+0}' <<< "${lastSheetNumber}") #trick to remove leading zero but get zero if the number contains only zeroes
        if [ ${EXHND_fixFinal} = 'TRUE' ]; then
            echo ${lastSheetNumber}
        else
            if [ ${EXHND_makeExerciseSheet} = 'TRUE' ] || [ ${EXHND_makeExam} = 'TRUE' ]; then
                echo $((lastSheetNumber+1))
            elif [ ${EXHND_makeSolutionSheet} = 'TRUE' ] || [ ${EXHND_makePresenceSheet} = 'TRUE' ]; then
                echo ${lastSheetNumber}
            else
                PrintInternal "Unexpected branch in \"${FUNCNAME[0]}\" function."
            fi
        fi
    else
        PrintError "Unable to determine sheet number!"; exit -1
    fi
}

function SetSheetNumber(){
    if [ ${EXHND_makeExerciseSheet} = 'FALSE' ] && [ ${EXHND_makeSolutionSheet} = 'FALSE' ] && [ ${EXHND_makeExam} = 'FALSE' ] && [ ${EXHND_makePresenceSheet} = 'FALSE' ]; then
        PrintInternal "Function \"${FUNCNAME[0]}\" called in unexpected scenario!"; exit -1
    fi
    if [ "${EXHND_sheetNumber}" = '' ]; then
        EXHND_sheetNumber=$(__static__DetermineSheetNumber)
        if [[ ! $EXHND_sheetNumber =~ ^[1-9][0-9]*$ ]]; then
            exit -1
        fi
    fi
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function CheckBlocksInFile(){
    local filename blocksName block
    filename="$1"; shift
    blocksName=( $@ )
    for block in "${blocksName[@]}"; do
        if [ $(grep -c "^[[:blank:]]*%__BEGIN_${block}__%[[:blank:]]*$" ${filename}) -ne 1 ] || [ $(grep -c "^[[:blank:]]*%__END_${block}__%[[:blank:]]*$" ${filename}) -ne 1 ]; then
            PrintError "Block %__BEGIN_${block}__%  ->  %__END_${block}__% not correctly found in \"${filename}\" file!"; exit -2
        fi
    done
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function CheckTexLocaldefsAndLatexTheme(){
    local line brackets oldIFS
    #Parse file line by line
    while read -r line || [[ -n "${line}" ]]; do # [[ -n "${line}" ]] is to read also last line if it does not end with \n
        if [[ $line =~ ^[[:space:]]*% ]]; then
            continue
        fi
        if [[ $line =~ \\def\\exerciseSheetSubtitlePrefix\{\} ]]; then # to skip optional fields in the check
            continue
        fi
        oldIFS=${IFS}
        IFS=$'\n'
        for brackets in $(grep -o "{[^{}]*}" <<< "${line}"); do
            if [ "$brackets" = '{}' ]; then
                PrintWarning "Found empty field(s) in \"${EXHND_texLocaldefsFilename}\"! Final result could be affected!"
                break 2
            fi
        done
        IFS=${oldIFS}
    done < "${EXHND_texLocaldefsFilename}"
    #General checks on blocks
    CheckBlocksInFile "${EXHND_texLocaldefsFilename}" "OPTIONS" "PACKAGES" "DEFINITIONS" "BODY"
    CheckBlocksInFile "${EXHND_themeFilename}" "PACKAGES" "DEFINITIONS"
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function __static__CheckSelectedFilesToBeUsed(){
    local file
    for file in ${EXHND_filesToBeUsedGlobalPath[@]}; do
        if [ ! -f ${file} ]; then
            PrintError "File \"$(basename ${file})\" not found in \"$(basename $(dirname ${file}))\" folder."; exit -1
        fi
        CheckBlocksInFile ${file} "OPTIONS" "PACKAGES" "DEFINITIONS" "BODY"
    done
}

function SetListOfFilesToBeUsedAndCheckThem(){
    local exercise
    if [ ${EXHND_makeExerciseSheet} = 'TRUE' ] || [ ${EXHND_makeExam} = 'TRUE' ]; then
        for exercise in ${EXHND_choosenExercises[@]}; do
            EXHND_filesToBeUsedGlobalPath+=( "${exercise/#/${EXHND_exercisePoolFolder}/}" )     #Prepend to each exercise the exercise pool (last / is a real / in path)
            if [ ${EXHND_showAlsoSolutions} = 'TRUE' ]; then
                EXHND_filesToBeUsedGlobalPath+=( "${exercise/#/${EXHND_solutionPoolFolder}/}" ) #Prepend to each exercise the solution pool (last / is a real / in path)
            fi
        done
    elif [ ${EXHND_makeSolutionSheet} = 'TRUE' ]; then
        for exercise in ${EXHND_choosenExercises[@]}; do
            if [ ${EXHND_showAlsoExercises} = 'TRUE' ]; then
                EXHND_filesToBeUsedGlobalPath+=( "${exercise/#/${EXHND_exercisePoolFolder}/}" ) #Prepend to each exercise the exercise pool (last / is a real / in path)
            fi
            EXHND_filesToBeUsedGlobalPath+=( "${exercise/#/${EXHND_solutionPoolFolder}/}" )     #Prepend to each exercise the solution pool (last / is a real / in path)
        done
    else
        PrintInternal "Function \"${FUNCNAME[0]}\" called in unexpected scenario!"; exit -1
    fi
    __static__CheckSelectedFilesToBeUsed
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function CreateTemporaryCompilationFolder(){
    [ -d "${EXHND_compilationFolder}" ] && mv "${EXHND_compilationFolder}" "${EXHND_compilationFolder}_$(date +%d.%m.%Y_%H%M%S)"
    mkdir "${EXHND_compilationFolder}" 2>/dev/null || { PrintError "Cannot create \"${EXHND_compilationFolder}\"!" && exit -2; }
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function __static__ExtractBlockFromFileAndAppendToAnotherFile(){
    local inputFilename outputFilename partOfDocument
    inputFilename="$1"
    outputFilename="$2"
    partOfDocument="$3"
    awk '/%__BEGIN_'${partOfDocument}'__%/,/%__END_'${partOfDocument}'__%/' ${inputFilename} | head -n -1 | tail -n +2 >> ${outputFilename}
}

function __static__ProduceTexAuxiliaryFile(){
    local outputFilename partOfDocument listOfFiles file
    outputFilename="$1"; partOfDocument="$2"; shift 2
    listOfFiles=( "$@" )
    if [[ ! ${partOfDocument} =~ ^(OPTIONS|PACKAGES|DEFINITIONS|BODY)$  ]]; then
        PrintInternal "Error in \"${FUNCNAME[0]}\" function, wrong partOfDocument passed! (partOfDocument=\"${partOfDocument}\")"; exit -1
    else
        if [[ ${partOfDocument} =~ ^(PACKAGES|DEFINITIONS)$  ]]; then
            __static__ExtractBlockFromFileAndAppendToAnotherFile  ${EXHND_vocabularyFilename}  ${outputFilename}  ${partOfDocument}
            __static__ExtractBlockFromFileAndAppendToAnotherFile  ${EXHND_themeFilename}  ${outputFilename}  ${partOfDocument}
        fi
        __static__ExtractBlockFromFileAndAppendToAnotherFile  ${EXHND_texLocaldefsFilename}  ${outputFilename}  ${partOfDocument}
        for file in "${listOfFiles[@]}"; do
            __static__ExtractBlockFromFileAndAppendToAnotherFile  ${file}  ${outputFilename}  ${partOfDocument}
        done
        #NOTE: We decided to use guards to divide the parts of the exercises file, because the parsing is then easier.
        #      For example, to extract packages one could do something like,
        #         awk '{split($0, res, "%"); if(res[1] !~ /^[ ]*$/){print res[1]}}' file.tex | sed 's/^[[:blank:]]*//g' | tr '\n' ' ' | grep -Eo '\\usepackage(\[[^]]*\])?{[^}]+}'
        #      but there are many cases that could break this down.
    fi
}

function ProduceTexAuxiliaryFiles(){
    __static__ProduceTexAuxiliaryFile ${EXHND_optionsFilename}     "OPTIONS"     "${EXHND_filesToBeUsedGlobalPath[@]}"
    __static__ProduceTexAuxiliaryFile ${EXHND_packagesFilename}    "PACKAGES"    "${EXHND_filesToBeUsedGlobalPath[@]}"
    __static__ProduceTexAuxiliaryFile ${EXHND_definitionsFilename} "DEFINITIONS" "${EXHND_filesToBeUsedGlobalPath[@]}"
    __static__ProduceTexAuxiliaryFile ${EXHND_bodyFilename}        "BODY"        "${EXHND_filesToBeUsedGlobalPath[@]}"
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function CheckTexPackagesFile(){
    PrintWarning "Function \"${FUNCNAME}\" not implemented yet! It is up to you to avoid conflicts in loading packages!"
}

function CheckTexDefinitionsFile(){
    PrintWarning "Function \"${FUNCNAME}\" not implemented yet! It is up to you to avoid conflicts between user commands!"
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function MakeCompilationInTemporaryFolder(){
    local index
    cd ${EXHND_compilationFolder}
    for index in {1..2}; do
        pdflatex -interaction=batchmode ${EXHND_mainFilename} >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            PrintError "Error occurred in pdflatex compilation!! Files can be found in \"${EXHND_compilationFolder}\" directory to investigate!"
            exit 0
        fi
    done
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function MovePdfFileToTemporaryFolderOpenItAndRemoveCompilationFolder(){
    local newPdfFilename
    if [ ${EXHND_makeExerciseSheet} = 'TRUE' ]; then
        newPdfFilename="${EXHND_temporaryFolder}/${EXHND_finalExerciseSheetPrefix}$(basename ${EXHND_mainFilename%.tex})_$(date +%d.%m.%Y_%H%M%S).pdf"
    elif [ ${EXHND_makeSolutionSheet} = 'TRUE' ]; then
        if [ ${EXHND_solutionOfExam} = 'TRUE' ]; then
            newPdfFilename="${EXHND_temporaryFolder}/${EXHND_finalExamSolutionPrefix}$(basename ${EXHND_mainFilename%.tex})_$(date +%d.%m.%Y_%H%M%S).pdf"
        else
            newPdfFilename="${EXHND_temporaryFolder}/${EXHND_finalSolutionSheetPrefix}$(basename ${EXHND_mainFilename%.tex})_$(date +%d.%m.%Y_%H%M%S).pdf"
        fi
    elif [ ${EXHND_makeExam} = 'TRUE' ]; then
        newPdfFilename="${EXHND_temporaryFolder}/${EXHND_finalExamSheetPrefix}$(basename ${EXHND_mainFilename%.tex})_$(date +%d.%m.%Y_%H%M%S).pdf"
    else
        PrintInternal "Function \"${FUNCNAME[0]}\" called in unexpected scenario!"; exit -1
    fi
    cp "${EXHND_mainFilename/.tex/.pdf}" "${newPdfFilename}" || exit -2
    cp "${EXHND_mainFilename/.tex/.pdf}" "${EXHND_temporaryPdfFilename}" || exit -2
    if [ $(lsof +D "${EXHND_temporaryFolder}" 2>/dev/null | awk 'NR>1{if($9 ~ /\.pdf$/){print $9}}' | grep -c "$(basename ${EXHND_temporaryPdfFilename})") -eq 0 ]; then
        PrintInfo "Created pdf file will be opened in a moment!"
        xdg-open "${EXHND_temporaryPdfFilename}" >/dev/null 2>&1 &
    fi
    rm -r "${EXHND_compilationFolder}"
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#

function __static__CreateExerciseLogfile(){
    local fileGlobalpath exercise
    fileGlobalpath=$1
    touch ${fileGlobalpath}
    for exercise in ${EXHND_choosenExercises[@]}; do
        printf "%2d    %s\n" ${EXHND_sheetNumber} ${exercise} >> ${fileGlobalpath}
    done
}

function MoveSheetFilesToFinalFolderOpenPdfAndRemoveCompilationFolder(){
    local destinationFolder newFilenameWithoutExtension texFile
    destinationFolder=$(GetFinalSheetFolderGlobalPathWithoutNumber) || exit -1
    destinationFolder+=$(printf "%02d" ${EXHND_sheetNumber})
    newFilenameWithoutExtension=$(basename ${destinationFolder})
    if [ -d "${destinationFolder}" ]; then
        if [ ${EXHND_makePresenceSheet} = 'TRUE' ]; then
            mv "${destinationFolder}" "${EXHND_temporaryFolder}/${newFilenameWithoutExtension}_$(date +%d.%m.%Y_%H%M%S)" || exit -2
            mkdir "${destinationFolder}" || exit -2
        else
            if [ ${EXHND_fixFinal} = 'FALSE' ]; then
                PrintError "Folder \"$(basename ${destinationFolder})\" for final sheet is already existing!"; exit -2
            else
                if [ "$(lsof +D "${destinationFolder}" 2>/dev/null)" != '' ]; then #std err of lsof is suppressed (it could contain warnings due to permissions on root files)
                    PrintError "Some process seems to be using some file in the" "  ${destinationFolder}" "folder. Cannot fix final sheet."; exit -1
                else
                    rm -r "${destinationFolder}" || exit -2
                    mkdir "${destinationFolder}" || exit -2
                fi
            fi
        fi
    else
        if [ ${EXHND_fixFinal} = 'TRUE' ]; then
            PrintError "The final sheet directory \"${destinationFolder/${EXHND_invokingDirectory}\//}\" does not exist! Impossible to make a fix."; exit -1
        fi
        mkdir "${destinationFolder}" || exit -2
    fi
    if [ ${EXHND_makeExerciseSheet} = 'TRUE' ]; then
        __static__CreateExerciseLogfile ${destinationFolder}/${EXHND_exercisesLogFilename}
    elif [ ${EXHND_makeExam} = 'TRUE' ]; then
        __static__CreateExerciseLogfile ${destinationFolder}/${EXHND_examLogFilename}
    fi
    #Rename .tex main file so that then I can move to final folder all .tex files from compilation folder
    #(moving before and renaming after is possible but require some more work)
    mv "${EXHND_mainFilename}"  "${EXHND_mainFilename%/*}/${newFilenameWithoutExtension}.tex" || exit -2
    for texFile in ${EXHND_compilationFolder}/*.tex; do
        mv "${texFile}" "${destinationFolder}"
    done
    cp "${EXHND_mainFilename/.tex/.pdf}" "${destinationFolder}/${newFilenameWithoutExtension}.pdf" || exit -2
    xdg-open "${destinationFolder}/${newFilenameWithoutExtension}.pdf" >/dev/null 2>&1 &
    rm -r "${EXHND_compilationFolder}"
}

#-------------------------------------------------------------------------------------------------------------------------------------------------------------#
