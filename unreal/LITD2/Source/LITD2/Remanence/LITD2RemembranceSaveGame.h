#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "LITD2RemembranceTypes.h"
#include "LITD2RemembranceSaveGame.generated.h"

UCLASS()
class LITD2_API ULITD2RemembranceSaveGame : public USaveGame
{
    GENERATED_BODY()

public:
    UPROPERTY(SaveGame)
    TMap<FName, ELITD2RemembranceDiscoveryState> EntryStates;

    UPROPERTY(SaveGame)
    TSet<FName> DiscoveredSourceIds;

    UPROPERTY(SaveGame)
    TSet<FName> CompletedReconstructionIds;

    UPROPERTY(SaveGame)
    TSet<FName> UnlockedIds;

    UPROPERTY(SaveGame)
    TMap<FName, int32> IntegerUnlockValues;
};
