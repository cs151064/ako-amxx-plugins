/***
*
*	Copyright (c) 1996-2001, Valve LLC. All rights reserved.
*
*	This product contains software technology licensed from Id
*	Software, Inc. ("Id Technology").  Id Technology (c) 1996 Id Software, Inc.
*	All Rights Reserved.
*
*   This source code contains proprietary and confidential information of
*   Valve LLC and its suppliers.  Access to this code is restricted to
*   persons who have executed a written SDK license with Valve.  Any access,
*   use or distribution of this code by or to any unlicensed person is illegal.
*
****/
//=========================================================
// Hutao
//=========================================================

#include	"extdll.h"
#include	"util.h"
#include	"cmbase.h"
#include	"cmbasemonster.h"
#include	"monsters.h"
#include	"schedule.h"
#include	"animation.h"

#define HUTAO_MODEL						"models/hutao/hutao.mdl"
#define HUTAO_KNIFE_RANGE				82
#define HUTAO_DASH_MIN_RANGE			110
#define HUTAO_DASH_MAX_RANGE			620
#define HUTAO_DASH_SPEED				760.0f
#define HUTAO_DASH_INTERVAL				4.0f
#define HUTAO_HEAVY_DAMAGE_THRESHOLD	30.0f
#define HUTAO_IDLE_VOICE_DURATION		9.5f
#define HUTAO_SHORT_VOICE_DURATION		1.5f
#define HUTAO_DEATH_VOICE_DURATION		3.0f
#define HUTAO_MAX_SP					100.0f
#define HUTAO_SP_ON_HIT					5.0f
#define HUTAO_SP_ON_PLAYER_KILL			25.0f
#define HUTAO_MAX_STAMINA				100.0f
#define HUTAO_SPRINT_MIN_STAMINA		20.0f
#define HUTAO_SPRINT_DRAIN_PER_SEC		22.0f
#define HUTAO_STAMINA_REGEN_PER_SEC		14.0f
#define HUTAO_SPRINT_FRAMERATE			1.35f

static const char *pHutaoIdleSounds[] =
{
	"hutao/Hu_Tao_Standby_01.wav",
	"hutao/Hu_Tao_Standby_02.wav",
};

static const char *pHutaoAttackSounds[] =
{
	"hutao/Hu_Tao_Light_Attack_01.wav",
	"hutao/Hu_Tao_Light_Attack_02.wav",
	"hutao/Hu_Tao_Light_Attack_03.wav",
	"hutao/Hu_Tao_Light_Attack_04.wav",
	"hutao/Hu_Tao_Light_Attack_05.wav",
	"hutao/Hu_Tao_Light_Attack_06.wav",
	"hutao/Hu_Tao_Light_Attack_07.wav",
};

static const char *pHutaoDashSounds[] =
{
	"hutao/Hu_Tao_Jumping_01.wav",
	"hutao/Hu_Tao_Jumping_02.wav",
	"hutao/Hu_Tao_Jumping_03.wav",
	"hutao/Hu_Tao_Jumping_04.wav",
	"hutao/Hu_Tao_Jumping_05.wav",
};

static const char *pHutaoSprintSounds[] =
{
	"hutao/Hu_Tao_Sprint_Start_01.wav",
	"hutao/Hu_Tao_Sprint_Start_02.wav",
	"hutao/Hu_Tao_Sprint_Start_03.wav",
};

static const char *pHutaoLightPainSounds[] =
{
	"hutao/Hu_Tao_Light_Hit_Taken_01.wav",
	"hutao/Hu_Tao_Light_Hit_Taken_02.wav",
	"hutao/Hu_Tao_Light_Hit_Taken_03.wav",
	"hutao/Hu_Tao_Light_Hit_Taken_04.wav",
	"hutao/Hu_Tao_Light_Hit_Taken_05.wav",
	"hutao/Hu_Tao_Light_Hit_Taken_06.wav",
};

static const char *pHutaoHeavyPainSounds[] =
{
	"hutao/Hu_Tao_Heavy_Hit_Taken_01.wav",
	"hutao/Hu_Tao_Heavy_Hit_Taken_02.wav",
	"hutao/Hu_Tao_Heavy_Hit_Taken_03.wav",
	"hutao/Hu_Tao_Heavy_Hit_Taken_04.wav",
	"hutao/Hu_Tao_Heavy_Hit_Taken_05.wav",
	"hutao/Hu_Tao_Heavy_Hit_Taken_06.wav",
};

static const char *pHutaoDeathSounds[] =
{
	"hutao/Hu_Tao_Fallen_01.wav",
	"hutao/Hu_Tao_Fallen_02.wav",
	"hutao/Hu_Tao_Fallen_03.wav",
};

static void HutaoLevelAim( CMBaseMonster *monster )
{
	monster->pev->angles.x = 0;
	monster->pev->v_angle.x = 0;
	monster->SetBoneController( 0, 0 );
	monster->SetBoneController( 1, 0 );
	monster->pev->blending[0] = 0;
	monster->pev->blending[1] = 0;
}

static const char *HutaoSequenceForActivity( Activity activity )
{
	switch ( activity )
	{
	case ACT_IDLE:
	case ACT_IDLE_ANGRY:
		return "idle1";
	case ACT_WALK:
		return "walk";
	case ACT_RUN:
		return "run";
	case ACT_MELEE_ATTACK1:
	case ACT_MELEE_ATTACK2:
	case ACT_RANGE_ATTACK1:
	case ACT_SPECIAL_ATTACK1:
		return "ref_shoot_knife";
	case ACT_SMALL_FLINCH:
	case ACT_BIG_FLINCH:
	case ACT_FLINCH_STOMACH:
		return "gut_flinch";
	case ACT_FLINCH_HEAD:
		return "head_flinch";
	case ACT_DIEFORWARD:
		return "forward";
	case ACT_DIEBACKWARD:
		return "back";
	case ACT_DIESIMPLE:
		return "death1";
	default:
		return "idle1";
	}
}

int CMHutao :: Classify ( void )
{
	if ( m_iClassifyOverride == -1 )
		return CLASS_NONE;
	else if ( m_iClassifyOverride > 0 )
		return m_iClassifyOverride;

	return CLASS_ALIEN_MONSTER;
}

void CMHutao :: SetYawSpeed( void )
{
	pev->yaw_speed = 120;
}

void CMHutao :: SetActivity( Activity NewActivity )
{
	const char *sequenceName = HutaoSequenceForActivity( NewActivity );
	int sequence = LookupSequence( sequenceName );

	if ( sequence == ACTIVITY_NOT_AVAILABLE )
		sequence = LookupSequence( "idle1" );

	if ( sequence == ACTIVITY_NOT_AVAILABLE )
		sequence = 0;

	if ( m_Activity == NewActivity && pev->sequence == sequence )
		return;

	m_Activity = NewActivity;
	m_IdealActivity = m_Activity;
	pev->sequence = sequence;
	pev->frame = 0;
	ResetSequenceInfo();
	if ( m_fSprinting && NewActivity == ACT_RUN )
		pev->framerate = HUTAO_SPRINT_FRAMERATE;
	SetYawSpeed();
	HutaoLevelAim( this );
}

BOOL CMHutao :: CheckMeleeAttack1( float flDot, float flDist )
{
	if ( m_flNextAttack > gpGlobals->time )
		return FALSE;

	return ( flDist <= HUTAO_KNIFE_RANGE && flDot >= 0.5 );
}

void CMHutao :: StartTask( Task_t *pTask )
{
	m_iTaskStatus = TASKSTATUS_RUNNING;

	switch ( pTask->iTask )
	{
	case TASK_MELEE_ATTACK1:
		KnifeAttack();
		TaskComplete();
		break;
	default:
		CMBaseMonster::StartTask( pTask );
		break;
	}
}

void CMHutao :: Spawn()
{
	BOOL hasCustomName = strlen( STRING( m_szMonsterName ) ) > 0;
	float customHealth = pev->health;

	Precache();

	SET_MODEL( ENT( pev ), HUTAO_MODEL );
	UTIL_SetSize( pev, VEC_HULL_MIN, VEC_HULL_MAX );

	pev->solid			= SOLID_SLIDEBOX;
	pev->movetype		= MOVETYPE_STEP;
	m_bloodColor		= BLOOD_COLOR_RED;
	pev->view_ofs		= VEC_VIEW;
	m_flFieldOfView		= 0.5;
	m_MonsterState		= MONSTERSTATE_NONE;
	m_afCapability		= bits_CAP_DOORS_GROUP | bits_CAP_MELEE_ATTACK1;

	pev->classname = MAKE_STRING( "monster_hutao" );
	if ( !hasCustomName )
		m_szMonsterName = MAKE_STRING( "Hutao" );

	pev->health = customHealth > 0 ? customHealth : gSkillData.hutaoHealth;
	pev->max_health = pev->health;
	m_iMaxHealth = (int)pev->max_health;
	m_flNextDash = gpGlobals->time + 1.0f;
	m_flNextIdleSound = gpGlobals->time + RANDOM_FLOAT( 3.0f, 7.0f );
	m_flNextPainSound = gpGlobals->time;
	m_flVoiceBusyUntil = gpGlobals->time;
	m_flSP = 0;
	m_flMaxSP = HUTAO_MAX_SP;
	m_flStamina = HUTAO_MAX_STAMINA;
	m_flMaxStamina = HUTAO_MAX_STAMINA;
	m_flSprintUntil = 0;
	m_flNextSprintDecision = gpGlobals->time + RANDOM_FLOAT( 0.8f, 1.8f );
	m_flNextSprintSound = gpGlobals->time;
	m_flLastThinkTime = gpGlobals->time;
	m_flLastDamage = 0;
	m_fDeathSoundPlayed = FALSE;
	m_fSprinting = FALSE;
	SetActivity( ACT_IDLE );
	HutaoLevelAim( this );

	MonsterInit();
}

void CMHutao :: Precache()
{
	PRECACHE_MODEL( HUTAO_MODEL );
	PRECACHE_SOUND_ARRAY( pHutaoIdleSounds );
	PRECACHE_SOUND_ARRAY( pHutaoAttackSounds );
	PRECACHE_SOUND_ARRAY( pHutaoDashSounds );
	PRECACHE_SOUND_ARRAY( pHutaoSprintSounds );
	PRECACHE_SOUND_ARRAY( pHutaoLightPainSounds );
	PRECACHE_SOUND_ARRAY( pHutaoHeavyPainSounds );
	PRECACHE_SOUND_ARRAY( pHutaoDeathSounds );
}

void CMHutao :: PrescheduleThink()
{
	if ( !IsAlive() )
		return;

	HutaoLevelAim( this );
	UpdateSprint();

	if ( m_MonsterState == MONSTERSTATE_IDLE && m_hEnemy == NULL && !IsMoving() && m_flNextIdleSound <= gpGlobals->time && m_flVoiceBusyUntil <= gpGlobals->time )
	{
		IdleSound();
	}

	if ( m_MonsterState != MONSTERSTATE_COMBAT )
		return;

	if ( m_flNextDash <= gpGlobals->time )
		DashTowardEnemy();
}

void CMHutao :: DashTowardEnemy( void )
{
	if ( m_hEnemy == NULL || !UTIL_IsAlive( m_hEnemy ) || !UTIL_FVisible( m_hEnemy, edict() ) )
	{
		m_flNextDash = gpGlobals->time + 1.0f;
		return;
	}

	Vector vecDir = m_hEnemy->v.origin - pev->origin;
	vecDir.z = 0;

	float flDist = vecDir.Length();
	if ( flDist < HUTAO_DASH_MIN_RANGE || flDist > HUTAO_DASH_MAX_RANGE )
	{
		m_flNextDash = gpGlobals->time + 1.0f;
		return;
	}

	vecDir = vecDir.Normalize();
	pev->ideal_yaw = UTIL_VecToYaw( vecDir );
	ChangeYaw( pev->yaw_speed );
	pev->velocity = pev->velocity + vecDir * HUTAO_DASH_SPEED;
	pev->velocity.z = 120;
	pev->flags &= ~FL_ONGROUND;

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoDashSounds ), 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_SHORT_VOICE_DURATION;
	SetActivity( ACT_RUN );
	m_flNextDash = gpGlobals->time + HUTAO_DASH_INTERVAL;
	m_flNextIdleSound = gpGlobals->time + RANDOM_FLOAT( 12.0f, 18.0f );
}

void CMHutao :: KnifeAttack( void )
{
	int attackSequence = LookupSequence( "ref_shoot_knife" );
	if ( attackSequence != ACTIVITY_NOT_AVAILABLE )
	{
		pev->sequence = attackSequence;
		pev->frame = 0;
		ResetSequenceInfo();
		HutaoLevelAim( this );
	}

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoAttackSounds ), 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_SHORT_VOICE_DURATION;
	m_flNextIdleSound = gpGlobals->time + RANDOM_FLOAT( 10.0f, 16.0f );

	edict_t *pHurt = CheckTraceHullAttack( HUTAO_KNIFE_RANGE, gSkillData.hutaoDmgKnife, DMG_SLASH );
	if ( pHurt && ( pHurt->v.flags & ( FL_MONSTER | FL_CLIENT ) ) )
	{
		BOOL wasPlayer = UTIL_IsPlayer( pHurt );
		AddSP( HUTAO_SP_ON_HIT );

		Vector vecKnock = pHurt->v.origin - pev->origin;
		vecKnock.z = 0;
		if ( vecKnock.Length() > 0 )
			vecKnock = vecKnock.Normalize();

		pHurt->v.velocity = pHurt->v.velocity + vecKnock * 180;
		pHurt->v.velocity.z += 90;

		if ( wasPlayer && !UTIL_IsAlive( pHurt ) )
			AddSP( HUTAO_SP_ON_PLAYER_KILL );
	}

	m_flNextAttack = gpGlobals->time + 0.8f;
}

void CMHutao :: AddSP( float amount )
{
	m_flSP += amount;
	if ( m_flSP > m_flMaxSP )
		m_flSP = m_flMaxSP;
}

void CMHutao :: UpdateSprint( void )
{
	float flDelta = gpGlobals->time - m_flLastThinkTime;
	if ( flDelta < 0 )
		flDelta = 0;
	if ( flDelta > 0.25f )
		flDelta = 0.25f;
	m_flLastThinkTime = gpGlobals->time;

	BOOL canSprint = FALSE;
	if ( m_MonsterState == MONSTERSTATE_COMBAT && m_hEnemy != NULL && UTIL_IsAlive( m_hEnemy ) )
	{
		Vector vecToEnemy = m_hEnemy->v.origin - pev->origin;
		vecToEnemy.z = 0;
		canSprint = ( vecToEnemy.Length() > HUTAO_KNIFE_RANGE * 1.6f && UTIL_FVisible( m_hEnemy, edict() ) );
	}

	if ( m_fSprinting )
	{
		m_flStamina -= HUTAO_SPRINT_DRAIN_PER_SEC * flDelta;
		if ( m_flStamina <= 0 || gpGlobals->time >= m_flSprintUntil || !canSprint )
		{
			if ( m_flStamina < 0 )
				m_flStamina = 0;
			m_fSprinting = FALSE;
			pev->framerate = 1.0f;
			m_flNextSprintDecision = gpGlobals->time + RANDOM_FLOAT( 1.0f, 2.2f );
		}
		else
		{
			m_movementActivity = ACT_RUN;
			if ( m_Activity == ACT_RUN )
				pev->framerate = HUTAO_SPRINT_FRAMERATE;
		}
		return;
	}

	if ( m_flStamina < m_flMaxStamina )
	{
		m_flStamina += HUTAO_STAMINA_REGEN_PER_SEC * flDelta;
		if ( m_flStamina > m_flMaxStamina )
			m_flStamina = m_flMaxStamina;
	}

	if ( !canSprint || m_flStamina < HUTAO_SPRINT_MIN_STAMINA || gpGlobals->time < m_flNextSprintDecision )
		return;

	if ( RANDOM_LONG( 0, 99 ) < 65 )
	{
		m_fSprinting = TRUE;
		m_flSprintUntil = gpGlobals->time + RANDOM_FLOAT( 1.2f, 3.2f );
		m_movementActivity = ACT_RUN;
		if ( m_Activity == ACT_RUN )
			pev->framerate = HUTAO_SPRINT_FRAMERATE;

		if ( m_flNextSprintSound <= gpGlobals->time )
		{
			EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoSprintSounds ), 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
			m_flVoiceBusyUntil = gpGlobals->time + HUTAO_SHORT_VOICE_DURATION;
			m_flNextSprintSound = gpGlobals->time + 1.8f;
		}
	}
	else
	{
		m_flNextSprintDecision = gpGlobals->time + RANDOM_FLOAT( 0.8f, 1.8f );
	}
}

int CMHutao :: TakeDamage( entvars_t *pevInflictor, entvars_t *pevAttacker, float flDamage, int bitsDamageType )
{
	m_flLastDamage = flDamage;
	return CMBaseMonster::TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );
}

void CMHutao :: Killed( entvars_t *pevAttacker, int iGib )
{
	if ( !HasMemory( bits_MEMORY_KILLED ) )
		DeathSound();

	CMBaseMonster::Killed( pevAttacker, iGib );
}

void CMHutao :: IdleSound( void )
{
	if ( m_MonsterState != MONSTERSTATE_IDLE || m_hEnemy != NULL || IsMoving() || m_flVoiceBusyUntil > gpGlobals->time || m_flNextIdleSound > gpGlobals->time )
		return;

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoIdleSounds ), 1.0, ATTN_IDLE, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_IDLE_VOICE_DURATION;
	m_flNextIdleSound = m_flVoiceBusyUntil + RANDOM_FLOAT( 6.0f, 12.0f );
}

void CMHutao :: PainSound( void )
{
	if ( m_flNextPainSound > gpGlobals->time )
		return;

	const char **sounds = m_flLastDamage >= HUTAO_HEAVY_DAMAGE_THRESHOLD ? pHutaoHeavyPainSounds : pHutaoLightPainSounds;
	int count = m_flLastDamage >= HUTAO_HEAVY_DAMAGE_THRESHOLD ? ARRAYSIZE( pHutaoHeavyPainSounds ) : ARRAYSIZE( pHutaoLightPainSounds );

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, sounds[ RANDOM_LONG( 0, count - 1 ) ], 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_SHORT_VOICE_DURATION;
	m_flNextPainSound = gpGlobals->time + 0.45f;
	m_flNextIdleSound = gpGlobals->time + RANDOM_FLOAT( 10.0f, 16.0f );
}

void CMHutao :: DeathSound( void )
{
	if ( m_fDeathSoundPlayed )
		return;

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoDeathSounds ), 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_DEATH_VOICE_DURATION;
	m_fDeathSoundPlayed = TRUE;
}
