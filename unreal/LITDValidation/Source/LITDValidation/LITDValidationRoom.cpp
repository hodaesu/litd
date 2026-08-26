#include "LITDValidationRoom.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

ALITDValidationRoom::ALITDValidationRoom()
{
    PrimaryActorTick.bCanEverTick = false;
    RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
}

void ALITDValidationRoom::OnConstruction(const FTransform& Transform)
{
    Super::OnConstruction(Transform);
    Rebuild();
}

void ALITDValidationRoom::Rebuild()
{
    for (UStaticMeshComponent* Component : Geometry)
    {
        if (IsValid(Component))
        {
            Component->DestroyComponent();
        }
    }
    Geometry.Reset();

    AddBlock(TEXT("Floor"), FVector(0, 0, -30), FVector(18, 15, 0.3), FLinearColor(0.14f, 0.13f, 0.17f));
    AddBlock(TEXT("NorthWall"), FVector(-1500, 0, 200), FVector(0.4f, 15, 2), FLinearColor(0.07f, 0.065f, 0.09f));
    AddBlock(TEXT("SouthWall"), FVector(1500, 0, 200), FVector(0.4f, 15, 2), FLinearColor(0.07f, 0.065f, 0.09f));
    AddBlock(TEXT("WestWall"), FVector(0, -1800, 200), FVector(15, 0.4f, 2), FLinearColor(0.07f, 0.065f, 0.09f));
    AddBlock(TEXT("EastWall"), FVector(0, 1800, 200), FVector(15, 0.4f, 2), FLinearColor(0.07f, 0.065f, 0.09f));
    AddBlock(TEXT("DialogueDais"), FVector(200, -900, 10), FVector(2.5f, 2.5f, 0.1f), FLinearColor(0.16f, 0.32f, 0.42f));
    AddBlock(TEXT("LootDais"), FVector(200, 900, 10), FVector(2.5f, 2.5f, 0.1f), FLinearColor(0.45f, 0.30f, 0.12f));
    AddBlock(TEXT("ArenaLine"), FVector(-700, 0, 4), FVector(0.15f, 16, 0.04f), FLinearColor(0.65f, 0.04f, 0.06f));
}

UStaticMeshComponent* ALITDValidationRoom::AddBlock(
    const FName Name, const FVector& Location, const FVector& Scale, const FLinearColor& Color)
{
    static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(TEXT("/Engine/BasicShapes/Cube.Cube"));
    UStaticMeshComponent* Component = NewObject<UStaticMeshComponent>(this, Name);
    Component->SetupAttachment(RootComponent);
    Component->SetStaticMesh(Cube.Object);
    Component->SetRelativeLocation(Location);
    Component->SetRelativeScale3D(Scale);
    Component->SetCollisionProfileName(TEXT("BlockAll"));
    Component->RegisterComponent();
    UMaterialInstanceDynamic* Material = Component->CreateAndSetMaterialInstanceDynamic(0);
    if (Material)
    {
        Material->SetVectorParameterValue(TEXT("BaseColor"), Color);
    }
    Geometry.Add(Component);
    return Component;
}
