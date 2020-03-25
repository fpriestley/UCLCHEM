!Marcus Keil 13/03/2020
!Python wrapper for uclchem, compiled with "make python"
!general becomes a python function which takes a dictionary of parameters
!and a string of delimited species names
SUBROUTINE General(dictionary, outSpeciesIn)
    USE physics
    USE chemistry
    IMPLICIT NONE
    CHARACTER (LEN=100) :: abundFile, outputFile, columnFile, outFile
    CHARACTER(LEN=*) :: dictionary, outSpeciesIn
    !f2py intent(in) dictionary,outSpeciesIn
    INTEGER :: posStart, posEnd, whileInteger
    CHARACTER(LEN=100) :: inputParameter, inputValue

    INCLUDE 'defaultparameters.f90'
    close(10)
    close(11)
    close(7)

    IF (scan(dictionary, 'columnFile') .EQ. 0) THEN
        columnFlag=.False.
    END IF

    whileInteger = 0

    posStart = scan(dictionary, '{')

    DO WHILE (whileInteger .NE. 1)
        posEnd = scan(dictionary, ':')
        inputParameter = dictionary(posStart+2:posEnd-2)
        dictionary = dictionary(posEnd:)
        posStart = scan(dictionary, ' ')
        IF (scan(dictionary, ',') .EQ. 0) THEN
            posEnd = scan(dictionary, '}')
            whileInteger = 1
        ELSE
            posEnd = scan(dictionary, ',')
        END IF
        inputValue = dictionary(posStart+1:posEnd-1)
        dictionary = dictionary(posEnd:)

        SELECT CASE (inputParameter)
            CASE('initialTemp')
                READ(inputValue,*) initialTemp
            CASE('maxTemp')
                READ(inputValue,*) maxTemp
            CASE('initialDens')
                READ(inputValue,*) initialDens
            CASE('finalDens')
                READ(inputValue,*) finalDens
            CASE('currentTime')
                READ(inputValue,*) currentTime
            CASE('finalTime')
                READ(inputValue,*) finalTime
            CASE('radfield')
                READ(inputValue,*) radfield
            CASE('zeta')
                READ(inputValue,*) zeta
            CASE('fr')
                READ(inputValue,*) fr
            CASE('rout')
                READ(inputValue,*) rout
            CASE('rin')
                READ(inputValue,*) rin
            CASE('baseAv')
                READ(inputValue,*) baseAv
            CASE('points')
                READ(inputValue,*) points
            CASE('switch')
                Read(inputValue,*) switch
            CASE('collapse')
                READ(inputValue,*) collapse
            CASE('bc')
                READ(inputValue,*) bc
            CASE('readAbunds')
                READ(inputValue,*) readAbunds
            CASE('phase')
                READ(inputValue,*) phase
            CASE('desorb')
                READ(inputValue,*) desorb
            CASE('h2desorb')
                READ(inputValue,*) h2desorb
            CASE('crdesorb')
                READ(inputValue,*) crdesorb
            CASE('uvdesorb')
                READ(inputValue,*) uvdesorb
            CASE('instantSublimation')
                READ(inputValue,*) instantSublimation
            CASE('ion')
                READ(inputValue,*) ion
            CASE('tempindx')
                READ(inputValue,*) tempindx
            CASE('fhe')
                READ(inputValue,*) fhe
            CASE('fc')
                READ(inputValue,*) fc
            CASE('fo')
                READ(inputValue,*) fo
            CASE('fn')
                READ(inputValue,*) fn
            CASE('fs')
                READ(inputValue,*) fs
            CASE('fmg')
                READ(inputValue,*) fmg
            CASE('fsi')
                READ(inputValue,*) fsi
            CASE('fcl')
                READ(inputValue,*) fcl
            CASE('fp')
                READ(inputValue,*) fp
            CASE('ff')
                READ(inputValue,*) ff
            CASE('outSpecies')
                IF (ALLOCATED(outIndx)) DEALLOCATE(outIndx)
                IF (ALLOCATED(outSpecies)) DEALLOCATE(outSpecies)
                READ(inputValue,*) nout
                ALLOCATE(outIndx(nout))
                ALLOCATE(outSpecies(nout))
                IF (outSpeciesIn .eq. "") THEN
                    write(*,*) "Outspecies parameter set but no outspecies string given"
                    write(*,*) "general(parameter_dict,outSpeciesIn) requires a delimited string of species names"
                    write(*,*) "if outSpecies or columnFlag is set in the parameter dictionary"
                    STOP
                ELSE
                    READ(outSpeciesIn,*, END=22) outSpecies
                    IF (outSpeciesIn .eq. "") THEN
22                      write(*,*) "mismatch between outSpeciesIn and number given in dictionary"
                        write(*,*) "Number:",nout
                        write(*,*) "Species list:",outSpeciesIn
                        STOP
                    END IF
                END IF
            CASE('writeStep')
                READ(inputValue,*) writeStep
            CASE('ebmaxh2')
                READ(inputValue,*) ebmaxh2
            CASE('epsilon')
                READ(inputValue,*) epsilon
            CASE('ebmaxcrf')
                READ(inputValue,*) ebmaxcrf
            CASE('uvcreff')
                READ(inputValue,*) uvcreff
            CASE('ebmaxcr')
                READ(inputValue,*) ebmaxcr
            CASE('phi')
                READ(inputValue,*) phi
            CASE('ebmaxuvcr')
                READ(inputValue,*) ebmaxuvcr
            CASE('uv_yield')
                READ(inputValue,*) uv_yield
            CASE('omega')
                READ(inputValue,*) omega
            CASE('vs')
                READ(inputValue,*) vs
            CASE('abundFile')
                READ(inputValue,*) abundFile
                abundFile = trim(abundFile)
                open(7,file=abundFile,status='unknown')
            CASE('outputFile')
                READ(inputValue,*) outFile
                outputFile = trim(outFile)
                open(10,file=outputFile,status='unknown')
            CASE('columnFile')
                IF (trim(outSpeciesIn) .NE. '' ) THEN
                    READ(inputValue,*) columnFile
                    columnFile = trim(columnFile)
                    open(11,file=columnFile,status='unknown')
                ELSE
                    WRITE(*,*) "Error in output species. No species were given but a column file was given."
                    WRITE(*,*) "columnated output requires output species to be chosen."
                    STOP
                END IF

            CASE DEFAULT
                WRITE(*,*) "Problem with given parameter: '", trim(inputParameter),"'. This is either not supported yet, or invalid"
        END SELECT
    END DO

    CALL initializePhysics
    CALL initializeChemistry

    dstep=1
    currentTime=0.0
    timeInYears=0.0

    !loop until the end condition of the model is reached
    DO WHILE ((switch .eq. 1 .and. density(1) < finalDens) .or. (switch .eq. 0 .and. timeInYears < finalTime))
        !store current time as starting point for each depth step
        currentTimeold=currentTime

        !Each physics module has a subroutine to set the target time from the current time
        CALL updateTargetTime

        !loop over parcels, counting from centre out to edge of cloud
        DO dstep=1,points
            !update chemistry from currentTime to targetTime
            CALL updateChemistry

            currentTime=targetTime
            !get time in years for output, currentTime is now equal to targetTime
            timeInYears= currentTime/SECONDS_PER_YEAR

            !Update physics so it's correct for new currentTime and start of next time step
            CALL updatePhysics
            !Sublimation checks if Sublimation should happen this time step and does it
            CALL sublimation(abund)
            !write this depth step now time, chemistry and physics are consistent
            CALL output

            !reset time for next depth point
            if (points .gt. 1)currentTime=currentTimeold
        END DO
    END DO 
    close(10)
    close(11)
    close(7)
END SUBROUTINE GENERAL