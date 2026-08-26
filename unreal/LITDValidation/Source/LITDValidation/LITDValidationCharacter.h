#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "LITDValidationCharacter.generated.h"

class USpringArmComponent;
class UCameraComponent;

UCLASS()
class LITDVALIDATION_API ALITDValidationCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ALITDValidationCharacter();
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
    virtual void Tick(float DeltaSeconds) override;

private:
    UPROPERTY()
    TObjectPtr<USpringArmComponent> CameraBoom;

    UPROPERTY()
    TObjectPtr<UCameraComponent> Camera;

    bool bMovementMarked = false;

    void MoveForward(float Value);
    void MoveRight(float Value);
    void Interact();
    void Attack();
    void AskAshGuidance();
    void ResetRoom();
};
