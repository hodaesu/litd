#include "LITDValidationStation.h"
#include "LITDValidationGameMode.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"

ALITDValidationStation::ALITDValidationStation()
{
    PrimaryActorTick.bCanEverTick = false;
    Visual = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Visual"));
    RootComponent = Visual;
    Visual->SetCollisionProfileName(TEXT("BlockAll"));
    if (UStaticMesh* Cube = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube")))
    {
        Visual->SetStaticMesh(Cube);
    }
}

void ALITDValidationStation::Configure(
    ELITDValidationStationType InType, const FString& InLabel, const FLinearColor& InColor)
{
    Type = InType;
    Label = InLabel;
    const FVector Scale = Type == ELITDValidationStationType::Dialogue
        ? FVector(0.65f, 0.65f, 1.8f)
        : FVector(1.2f, 0.8f, 0.65f);
    Visual->SetRelativeScale3D(Scale);
    UMaterialInstanceDynamic* Material = Visual->CreateAndSetMaterialInstanceDynamic(0);
    if (Material)
    {
        Material->SetVectorParameterValue(TEXT("BaseColor"), InColor);
    }
}

FString ALITDValidationStation::Prompt() const
{
    if (Type == ELITDValidationStationType::LootChest && bConsumed)
    {
        return TEXT("Coffre déjà ouvert");
    }
    return Label;
}

void ALITDValidationStation::Interact(APawn* InstigatorPawn)
{
    ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr;
    if (!Mode)
    {
        return;
    }

    switch (Type)
    {
        case ELITDValidationStationType::Dialogue:
            Mode->PresentDialogue(TEXT("Ilyan"), TEXT("Cette salle vérifie les interactions, le coffre, le combat et les états corporels."));
            Mode->MarkCheck(TEXT("dialogue"));
            break;
        case ELITDValidationStationType::LootChest:
            if (!bConsumed)
            {
                bConsumed = true;
                Mode->GrantPrototypeLoot(TEXT("Lame inhabituelle d'essai"), 1);
                Mode->MarkCheck(TEXT("chest"));
                Mode->MarkCheck(TEXT("loot"));
            }
            break;
        case ELITDValidationStationType::AshGuidance:
            Mode->RequestAshGuidance(FVector(-1150, 0, 20));
            Mode->MarkCheck(TEXT("ash_guidance"));
            break;
        case ELITDValidationStationType::Psychology:
            Mode->PresentMessage(TEXT("Postures injectées : Effrayé, Inspiré et Affligé."));
            Mode->MarkCheck(TEXT("psychology"));
            break;
        case ELITDValidationStationType::PersistentInjury:
            Mode->PresentMessage(TEXT("Bras blessé sérieux : malus persistant jusqu'au soin."));
            Mode->MarkCheck(TEXT("injury"));
            break;
        case ELITDValidationStationType::SaveRoundtrip:
            Mode->RunSnapshotRoundtrip();
            break;
    }
}
