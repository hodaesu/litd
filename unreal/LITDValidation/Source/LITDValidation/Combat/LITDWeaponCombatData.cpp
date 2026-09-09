#include "Combat/LITDWeaponCombatData.h"

FName ULITDWeaponCombatData::ResolveDefaultActionId(const ELITDCombatInput Input) const
{
    switch (Input)
    {
    case ELITDCombatInput::Light: return LightActionId;
    case ELITDCombatInput::Heavy: return HeavyActionId;
    case ELITDCombatInput::Parry: return ParryActionId;
    case ELITDCombatInput::Dodge: return DodgeActionId;
    case ELITDCombatInput::SkillAttack: return SkillAttackActionId;
    default: return NAME_None;
    }
}
