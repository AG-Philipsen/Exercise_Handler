function DefineGlobalVariables(){

    #Global internal variables
    readonly EXHND_themeFilename="${EXHND_repositoryDirectory}/ClassicTheme.tex"
    readonly EXHND_invokingDirectory="$(pwd)"
    readonly EXHND_texLocaldefsFilename="${EXHND_invokingDirectory}/TexLocaldefs.tex"
    readonly EXHND_exercisePoolFolder="${EXHND_invokingDirectory}/Exercises"
    readonly EXHND_solutionPoolFolder="${EXHND_invokingDirectory}/Solutions"
    readonly EXHND_finalExerciseSheetFolder="${EXHND_invokingDirectory}/FinalExerciseSheets"
    readonly EXHND_exercisesLogFilename=".exercises.log" #One in each final exSheet folder
    readonly EXHND_finalSolutionSheetFolder="${EXHND_invokingDirectory}/FinalSolutionSheets"
    readonly EXHND_figuresFolder="${EXHND_invokingDirectory}/Figures"
    readonly EXHND_temporaryFolder="${EXHND_invokingDirectory}/tmp"
    readonly EXHND_compilationFolder="${EXHND_temporaryFolder}/TemporaryCompilationFolder"
    readonly EXHND_packagesFilename="${EXHND_compilationFolder}/Packages.tex"
    readonly EXHND_definitionsFilename="${EXHND_compilationFolder}/Definitions.tex"
    readonly EXHND_bodyFilename="${EXHND_compilationFolder}/Document.tex"
    readonly EXHND_mainFilename="${EXHND_compilationFolder}/ExerciseSheet.tex"
    EXHND_exerciseList=(); EXHND_choosenExercises=() #These arrays contain the basenames of the files

    #Variables with input from user
    EXHND_exerciseSheetSubtitlePostfix=''
    EXHND_exerciseSheetNumber=''
    EXHND_exercisesFromPoolAsNumbers=''

    #Mutually exclusive options
    EXHND_doSetup='FALSE'
    EXHND_produceNewExercise='FALSE'
    EXHND_makeExerciseSheet='FALSE'
    EXHND_listUsedExercises='FALSE'

    #Behaviour options
    EXHND_isFinal='FALSE'
    EXHND_fixFinal='FALSE'
    EXHND_displayAlreadyUsedExercises='FALSE'

}
