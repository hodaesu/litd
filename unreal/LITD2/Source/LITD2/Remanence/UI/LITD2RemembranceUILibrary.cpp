#include "Remanence/UI/LITD2RemembranceUILibrary.h"

#include "GameFramework/PlayerController.h"
#include "Remanence/UI/LITD2RemembranceArchiveScreen.h"

ULITD2RemembranceArchiveScreen* ULITD2RemembranceUILibrary::OpenRemanenceArchive(
    APlayerController* OwningPlayer,
    TSubclassOf<ULITD2RemembranceArchiveScreen> WidgetClass)
{
    if (!OwningPlayer)
    {
        return nullptr;
    }

    TSubclassOf<ULITD2RemembranceArchiveScreen> ResolvedClass = WidgetClass;
    if (!ResolvedClass)
    {
        ResolvedClass = ULITD2RemembranceArchiveScreen::StaticClass();
    }

    ULITD2RemembranceArchiveScreen* Screen = CreateWidget<ULITD2RemembranceArchiveScreen>(OwningPlayer, ResolvedClass);
    if (!Screen)
    {
        return nullptr;
    }

    Screen->AddToViewport(80);

    FInputModeGameAndUI InputMode;
    InputMode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
    InputMode.SetHideCursorDuringCapture(false);
    InputMode.SetWidgetToFocus(Screen->TakeWidget());
    OwningPlayer->SetInputMode(InputMode);
    OwningPlayer->SetShowMouseCursor(true);

    return Screen;
}

void ULITD2RemembranceUILibrary::CloseRemanenceArchive(
    APlayerController* OwningPlayer,
    ULITD2RemembranceArchiveScreen* ArchiveScreen)
{
    if (ArchiveScreen)
    {
        ArchiveScreen->RemoveFromParent();
    }

    if (OwningPlayer)
    {
        FInputModeGameOnly InputMode;
        OwningPlayer->SetInputMode(InputMode);
        OwningPlayer->SetShowMouseCursor(false);
    }
}
