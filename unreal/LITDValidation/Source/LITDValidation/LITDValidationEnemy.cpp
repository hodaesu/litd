#include "LITDValidationEnemy.h"
#include "LITDValidationGameMode.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"

ALITDValidationEnemy::ALITDValidationEnemy()
{
    PrimaryActorTick.bCanEverTick = false;
    Visual = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Visual"));
    RootComponent = Visual;
    Visual->SetCollisionProfileName(TEXT("BlockAll"));
    Visual->SetRelativeScale3D(FVector(0.7f, 0.7f, 1.4f));
    if (UStaticMesh* Cube = LoadObject<UStaticMesh>(nullptr, TEXT("/Engine/BasicShapes/Cube.Cube")))
    {
        Visual->SetStaticMesh(Cube);
    }
}

void ALITDValidationEnemy::Configure(int32 Index)
{
    Health = MaxHealth = 70.0f + Index * 12.0f;
    Material = Visual->CreateAndSetMaterialInstanceDynamic(0);
    RefreshColor();
}

void ALITDValidationEnemy::ReceiveTestDamage(float Amount)
{
    if (bDefeated)
    {
        return;
    }
    Health = FMath::Max(0.0f, Health - FMath::Max(0.0f, Amount));
    bDefeated = Health <= 0.0f;
    RefreshColor();

    if (ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr)
    {
        Mode->MarkCheck(TEXT("combat_started"));
        if (bDefeated)
        {
            Mode->RegisterEnemyDefeated();
        }
        else if (IsCapturable())
        {
            Mode->PresentMessage(TEXT("◇ CAPTURABLE — barre vert-cendre"));
        }
    }
}

bool ALITDValidationEnemy::IsCapturable() const
{
    return !bDefeated && HealthRatio() <= 0.35f;
}

float ALITDValidationEnemy::HealthRatio() const
{
    return MaxHealth > 0.0f ? Health / MaxHealth : 0.0f;
}

void ALITDValidationEnemy::RefreshColor()
{
    if (!Material)
    {
        return;
    }
    const FLinearColor Color = bDefeated
        ? FLinearColor(0.06f, 0.06f, 0.06f)
        : IsCapturable()
            ? FLinearColor(0.28f, 0.55f, 0.39f)
            : FLinearColor(0.58f, 0.04f, 0.06f);
    Material->SetVectorParameterValue(TEXT("BaseColor"), Color);
}
