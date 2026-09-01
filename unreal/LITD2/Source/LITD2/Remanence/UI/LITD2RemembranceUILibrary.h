#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "LITD2RemembranceUILibrary.generated.h"

class APlayerController;
class ULITD2RemembranceArchiveScreen;

UCLASS()
class LITD2_API ULITD2RemembranceUILibrary : public UBlueprintFunctionLibrary
{
    GENERATED_BODY()

public:
    /** Opens the native archive screen or a Widget Blueprint child such as WBP_RemembranceArchive. */
    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Archive UI")
    static ULITD2RemembranceArchiveScreen* OpenRemanenceArchive(
        APlayerController* OwningPlayer,
        TSubclassOf<ULITD2RemembranceArchiveScreen> WidgetClass);

    /** Removes the archive screen and restores game-only input. */
    UFUNCTION(BlueprintCallable, Category="LITD2|Remanence|Archive UI")
    static void CloseRemanenceArchive(
        APlayerController* OwningPlayer,
        ULITD2RemembranceArchiveScreen* ArchiveScreen);
};
