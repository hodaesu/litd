#include "LITDValidationCharacter.h"
#include "LITDValidationEnemy.h"
#include "LITDValidationGameMode.h"
#include "LITDValidationStation.h"
#include "Camera/CameraComponent.h"
#include "Components/InputComponent.h"
#include "Engine/World.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/SpringArmComponent.h"

ALITDValidationCharacter::ALITDValidationCharacter()
{
    PrimaryActorTick.bCanEverTick = true;
    GetCharacterMovement()->MaxWalkSpeed = 450.0f;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 540.0f, 0.0f);
    bUseControllerRotationYaw = false;

    CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
    CameraBoom->SetupAttachment(RootComponent);
    CameraBoom->TargetArmLength = 1100.0f;
    CameraBoom->SetRelativeRotation(FRotator(-48.0f, 0.0f, 0.0f));
    CameraBoom->bDoCollisionTest = true;

    Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
    Camera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
    Camera->bUsePawnControlRotation = false;
}

void ALITDValidationCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);
    PlayerInputComponent->BindAxis(TEXT("MoveForward"), this, &ALITDValidationCharacter::MoveForward);
    PlayerInputComponent->BindAxis(TEXT("MoveRight"), this, &ALITDValidationCharacter::MoveRight);
    PlayerInputComponent->BindAction(TEXT("Interact"), IE_Pressed, this, &ALITDValidationCharacter::Interact);
    PlayerInputComponent->BindAction(TEXT("Attack"), IE_Pressed, this, &ALITDValidationCharacter::Attack);
    PlayerInputComponent->BindAction(TEXT("AshGuidance"), IE_Pressed, this, &ALITDValidationCharacter::AskAshGuidance);
    PlayerInputComponent->BindAction(TEXT("ResetValidation"), IE_Pressed, this, &ALITDValidationCharacter::ResetRoom);
}

void ALITDValidationCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (!bMovementMarked && GetVelocity().SizeSquared2D() > 25.0f)
    {
        bMovementMarked = true;
        if (ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr)
        {
            Mode->MarkCheck(TEXT("movement"));
        }
    }
}

void ALITDValidationCharacter::MoveForward(float Value)
{
    AddMovementInput(FVector(-1, 0, 0), Value);
}

void ALITDValidationCharacter::MoveRight(float Value)
{
    AddMovementInput(FVector(0, 1, 0), Value);
}

void ALITDValidationCharacter::Interact()
{
    if (!GetWorld())
    {
        return;
    }
    const FVector Start = GetActorLocation() + FVector(0, 0, 70);
    const FVector End = Start + GetActorForwardVector() * 280.0f;
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(LITDInteract), false, this);
    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        if (ALITDValidationStation* Station = Cast<ALITDValidationStation>(Hit.GetActor()))
        {
            Station->Interact(this);
        }
    }
}

void ALITDValidationCharacter::Attack()
{
    if (!GetWorld())
    {
        return;
    }
    const FVector Start = GetActorLocation() + FVector(0, 0, 70);
    const FVector End = Start + GetActorForwardVector() * 650.0f;
    FHitResult Hit;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(LITDAttack), false, this);
    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        if (ALITDValidationEnemy* Enemy = Cast<ALITDValidationEnemy>(Hit.GetActor()))
        {
            Enemy->ReceiveTestDamage(28.0f);
        }
    }
}

void ALITDValidationCharacter::AskAshGuidance()
{
    if (ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr)
    {
        Mode->RequestAshGuidance(FVector(-1150, 0, 20));
    }
}

void ALITDValidationCharacter::ResetRoom()
{
    if (ALITDValidationGameMode* Mode = GetWorld() ? Cast<ALITDValidationGameMode>(GetWorld()->GetAuthGameMode()) : nullptr)
    {
        Mode->ResetValidation();
    }
}
