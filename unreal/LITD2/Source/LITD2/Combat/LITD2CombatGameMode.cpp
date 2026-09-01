#include "Combat/LITD2CombatGameMode.h"

#include "Combat/LITD2PlayerCombatCharacter.h"

ALITD2CombatGameMode::ALITD2CombatGameMode()
{
    DefaultPawnClass = ALITD2PlayerCombatCharacter::StaticClass();
}
