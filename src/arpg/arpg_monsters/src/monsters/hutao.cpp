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
#include	"arpg_monster_paths.h"

#define HUTAO_MODEL						ARPG_HUTAO_MODEL
#define HUTAO_KNIFE_RANGE				82
#define HUTAO_DASH_MIN_RANGE			110
#define HUTAO_DASH_MAX_RANGE			620
#define HUTAO_DASH_SPEED				760.0f
#define HUTAO_DASH_INTERVAL				4.0f
#define HUTAO_HEAVY_MIN_RANGE			135
#define HUTAO_HEAVY_MAX_RANGE			560
#define HUTAO_HEAVY_SPEED				980.0f
#define HUTAO_HEAVY_DURATION			0.45f
#define HUTAO_HEAVY_INTERVAL			7.0f
#define HUTAO_HEAVY_HIT_RADIUS			72.0f
#define HUTAO_HEAVY_MAX_HITS			16
#define HUTAO_HEAVY_STAMINA_COST		20.0f
#define HUTAO_BURN_DURATION				1.3f
#define HUTAO_BURN_TICK					0.25f
#define HUTAO_FLAME_LIFETIME			1.8f
#define HUTAO_FLAME_RADIUS				46.0f
#define HUTAO_FLAME_TICK				0.3f
#define HUTAO_DEATH_CLEANUP_DELAY		1.8f
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

static int g_iHutaoFlameSprite = 0;

static const char *pHutaoIdleSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Standby_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Standby_02.wav",
};

static const char *pHutaoAttackSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_03.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_04.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_05.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_06.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Attack_07.wav",
};

static const char *pHutaoDashSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Jumping_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Jumping_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Jumping_03.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Jumping_04.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Jumping_05.wav",
};

static const char *pHutaoSprintSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Sprint_Start_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Sprint_Start_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Sprint_Start_03.wav",
};

static const char *pHutaoLightPainSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_03.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_04.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_05.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Light_Hit_Taken_06.wav",
};

static const char *pHutaoHeavyPainSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_03.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_04.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_05.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Heavy_Hit_Taken_06.wav",
};

class CMHutaoBurn : public CMBaseEntity
{
public:
	void SpawnOn( edict_t *pVictim, edict_t *pOwner );
	void EXPORT BurnThink( void );

	EHANDLE m_hVictim;
	EHANDLE m_hOwner;
	float m_flExpireTime;
	float m_flNextDamage;
	float m_flNextEffect;
};

class CMHutaoFlame : public CMBaseEntity
{
public:
	void SpawnAt( const Vector &origin, edict_t *pOwner );
	void EXPORT FlameThink( void );

	EHANDLE m_hOwner;
	float m_flExpireTime;
	float m_flNextDamage;
	float m_flNextEffect;
	EHANDLE m_hBurnTargets[16];
	int m_iBurnTargetCount;
};

static const char *pHutaoDeathSounds[] =
{
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Fallen_01.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Fallen_02.wav",
	ARPG_HUTAO_SOUND_PREFIX "Hu_Tao_Fallen_03.wav",
};

static void HutaoShowFireField( const Vector &origin, float radius, int count, float duration )
{
	if ( g_iHutaoFlameSprite <= 0 )
		return;

	for ( int i = 0; i < count; i++ )
	{
		Vector vecPos = origin;
		vecPos.x += RANDOM_FLOAT( -radius, radius );
		vecPos.y += RANDOM_FLOAT( -radius, radius );
		vecPos.z += RANDOM_FLOAT( 4, 18 );

		MESSAGE_BEGIN( MSG_PVS, SVC_TEMPENTITY, vecPos );
			WRITE_BYTE( TE_SPRITE );
			WRITE_COORD( vecPos.x );
			WRITE_COORD( vecPos.y );
			WRITE_COORD( vecPos.z );
			WRITE_SHORT( g_iHutaoFlameSprite );
			WRITE_BYTE( 4 );
			WRITE_BYTE( 180 );
		MESSAGE_END();
	}

	MESSAGE_BEGIN( MSG_PVS, SVC_TEMPENTITY, origin );
		WRITE_BYTE( TE_DLIGHT );
		WRITE_COORD( origin.x );
		WRITE_COORD( origin.y );
		WRITE_COORD( origin.z + 12 );
		WRITE_BYTE( 5 );
		WRITE_BYTE( 255 );
		WRITE_BYTE( 95 );
		WRITE_BYTE( 20 );
		WRITE_BYTE( 120 );
		WRITE_BYTE( (int)( duration * 10 ) );
		WRITE_BYTE( 80 );
	MESSAGE_END();
}

static BOOL HutaoCanDamageTarget( edict_t *pTarget, edict_t *pOwner )
{
	if ( pTarget == NULL || pTarget == pOwner || pTarget->free )
		return FALSE;
	if ( !( pTarget->v.flags & ( FL_CLIENT | FL_MONSTER ) ) )
		return FALSE;
	if ( !pTarget->v.takedamage || !UTIL_IsAlive( pTarget ) )
		return FALSE;

	if ( pOwner != NULL && pOwner->v.euser4 != NULL )
	{
		CMBaseMonster *pOwnerMonster = GetClassPtr( (CMBaseMonster *)VARS( pOwner ) );
		if ( pOwnerMonster != NULL )
		{
			int targetClass = UTIL_IsPlayer( pTarget ) ? CLASS_PLAYER : pTarget->v.iuser4;
			if ( pOwnerMonster->IRelationship( targetClass ) <= R_NO )
				return FALSE;
		}
	}

	return TRUE;
}

static BOOL HutaoDamageTarget( edict_t *pTarget, edict_t *pOwner, entvars_t *pevInflictor, float damage, int bitsDamageType )
{
	if ( !HutaoCanDamageTarget( pTarget, pOwner ) )
		return FALSE;

	entvars_t *pevAttacker = pOwner != NULL ? VARS( pOwner ) : pevInflictor;
	if ( UTIL_IsPlayer( pTarget ) )
		return UTIL_TakeDamage( pTarget, pevInflictor, pevAttacker, damage, bitsDamageType );

	CMBaseMonster *pMonster = GetClassPtr( (CMBaseMonster *)VARS( pTarget ) );
	if ( pMonster == NULL )
		return FALSE;

	return pMonster->TakeDamage( pevInflictor, pevAttacker, damage, bitsDamageType );
}

static void HutaoApplyBurn( edict_t *pVictim, edict_t *pOwner )
{
	CMHutaoBurn *pBurn = CreateClassPtr( (CMHutaoBurn *)NULL );
	if ( pBurn == NULL )
		return;

	pBurn->SpawnOn( pVictim, pOwner );
}

static void HutaoSpawnFlame( const Vector &origin, edict_t *pOwner )
{
	CMHutaoFlame *pFlame = CreateClassPtr( (CMHutaoFlame *)NULL );
	if ( pFlame == NULL )
		return;

	pFlame->SpawnAt( origin, pOwner );
}

void CMHutaoBurn :: SpawnOn( edict_t *pVictim, edict_t *pOwner )
{
	pev->classname = MAKE_STRING( "hutao_burn" );
	pev->solid = SOLID_NOT;
	pev->movetype = MOVETYPE_NONE;
	pev->effects |= EF_NODRAW;
	m_hVictim = pVictim;
	m_hOwner = pOwner;
	m_flExpireTime = gpGlobals->time + HUTAO_BURN_DURATION;
	m_flNextDamage = gpGlobals->time;
	m_flNextEffect = gpGlobals->time;
	SetThink( &CMHutaoBurn::BurnThink );
	pev->nextthink = gpGlobals->time + 0.05f;
}

void CMHutaoBurn :: BurnThink( void )
{
	edict_t *pVictim = m_hVictim.Get();
	edict_t *pOwner = m_hOwner.Get();

	if ( pVictim == NULL || !UTIL_IsAlive( pVictim ) || gpGlobals->time >= m_flExpireTime )
	{
		SetThink( &CMBaseEntity::SUB_Remove );
		pev->nextthink = gpGlobals->time;
		return;
	}

	UTIL_SetOrigin( pev, pVictim->v.origin );

	if ( m_flNextEffect <= gpGlobals->time )
	{
		HutaoShowFireField( pVictim->v.origin, 14, 2, 0.45f );
		m_flNextEffect = gpGlobals->time + 0.45f;
	}

	if ( m_flNextDamage <= gpGlobals->time )
	{
		HutaoDamageTarget( pVictim, pOwner, pev, gSkillData.hutaoDmgFlame, DMG_BURN | DMG_SLOWBURN | DMG_NEVERGIB );
		m_flNextDamage = gpGlobals->time + HUTAO_BURN_TICK;
	}

	pev->nextthink = gpGlobals->time + 0.05f;
}

void CMHutaoFlame :: SpawnAt( const Vector &origin, edict_t *pOwner )
{
	pev->classname = MAKE_STRING( "hutao_flame" );
	pev->solid = SOLID_NOT;
	pev->movetype = MOVETYPE_NONE;
	pev->effects |= EF_NODRAW;
	pev->owner = pOwner;
	m_hOwner = pOwner;
	m_flExpireTime = gpGlobals->time + HUTAO_FLAME_LIFETIME;
	m_flNextDamage = gpGlobals->time;
	m_flNextEffect = gpGlobals->time;
	m_iBurnTargetCount = 0;
	UTIL_SetOrigin( pev, origin );
	UTIL_SetSize( pev, Vector( -HUTAO_FLAME_RADIUS, -HUTAO_FLAME_RADIUS, 0 ), Vector( HUTAO_FLAME_RADIUS, HUTAO_FLAME_RADIUS, 48 ) );
	HutaoShowFireField( origin, HUTAO_FLAME_RADIUS, 3, HUTAO_FLAME_LIFETIME );
	SetThink( &CMHutaoFlame::FlameThink );
	pev->nextthink = gpGlobals->time + 0.05f;
}

void CMHutaoFlame :: FlameThink( void )
{
	if ( gpGlobals->time >= m_flExpireTime )
	{
		SetThink( &CMBaseEntity::SUB_Remove );
		pev->nextthink = gpGlobals->time;
		return;
	}

	if ( m_flNextEffect <= gpGlobals->time )
	{
		HutaoShowFireField( pev->origin, HUTAO_FLAME_RADIUS, 3, 0.6f );
		m_flNextEffect = gpGlobals->time + 0.6f;
	}

	if ( m_flNextDamage <= gpGlobals->time )
	{
		edict_t *targets[32];
		int count = UTIL_MonstersInSphere( targets, ARRAYSIZE( targets ), pev->origin, HUTAO_FLAME_RADIUS );
		edict_t *pOwner = m_hOwner.Get();

		for ( int i = 0; i < count; i++ )
		{
			edict_t *pTarget = targets[i];
			if ( !HutaoDamageTarget( pTarget, pOwner, pev, gSkillData.hutaoDmgFlame, DMG_BURN | DMG_SLOWBURN | DMG_NEVERGIB ) )
				continue;

			BOOL alreadyBurning = FALSE;
			for ( int burn = 0; burn < m_iBurnTargetCount; burn++ )
			{
				if ( m_hBurnTargets[burn] == pTarget )
				{
					alreadyBurning = TRUE;
					break;
				}
			}

			if ( !alreadyBurning )
			{
				HutaoApplyBurn( pTarget, pOwner );
				if ( m_iBurnTargetCount < ARRAYSIZE( m_hBurnTargets ) )
					m_hBurnTargets[m_iBurnTargetCount++] = pTarget;
			}
		}

		m_flNextDamage = gpGlobals->time + HUTAO_FLAME_TICK;
	}

	pev->nextthink = gpGlobals->time + 0.05f;
}

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
	m_flNextHeavyAttack = gpGlobals->time + RANDOM_FLOAT( 2.5f, 4.5f );
	m_flHeavyAttackUntil = 0;
	m_flNextHeavyFlame = gpGlobals->time;
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
	m_flDeadCleanupTime = 0;
	m_vecHeavyAttackDir = g_vecZero;
	m_vecHeavyLastOrigin = pev->origin;
	m_iHeavyHitCount = 0;
	m_fDeathSoundPlayed = FALSE;
	m_fSprinting = FALSE;
	m_fHeavyAttacking = FALSE;
	SetActivity( ACT_IDLE );
	HutaoLevelAim( this );

	MonsterInit();
}

void CMHutao :: Precache()
{
	PRECACHE_MODEL( HUTAO_MODEL );
	g_iHutaoFlameSprite = PRECACHE_MODELINDEX( ARPG_HUTAO_FLAME_SPRITE );
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
	if ( m_flDeadCleanupTime > 0 )
	{
		if ( gpGlobals->time >= m_flDeadCleanupTime )
			RemoveDeadBody();
		return;
	}

	if ( !IsAlive() )
		return;

	if ( pev->deadflag != DEAD_NO || m_MonsterState == MONSTERSTATE_DEAD || m_IdealMonsterState == MONSTERSTATE_DEAD )
		return;

	HutaoLevelAim( this );
	UpdateHeavyAttack();

	if ( m_fHeavyAttacking )
		return;

	UpdateSprint();

	if ( m_MonsterState == MONSTERSTATE_IDLE && m_hEnemy == NULL && !IsMoving() && m_flNextIdleSound <= gpGlobals->time && m_flVoiceBusyUntil <= gpGlobals->time )
	{
		IdleSound();
	}

	if ( m_MonsterState != MONSTERSTATE_COMBAT )
		return;

	if ( m_flNextHeavyAttack <= gpGlobals->time )
		TryHeavyAttack();

	if ( m_fHeavyAttacking )
		return;

	if ( m_flNextDash <= gpGlobals->time )
		DashTowardEnemy();
}

void CMHutao :: TryHeavyAttack( void )
{
	if ( m_flStamina < HUTAO_HEAVY_STAMINA_COST )
	{
		m_flNextHeavyAttack = gpGlobals->time + 1.0f;
		return;
	}

	if ( m_hEnemy == NULL || !UTIL_IsAlive( m_hEnemy ) || !UTIL_FVisible( m_hEnemy, edict() ) )
	{
		m_flNextHeavyAttack = gpGlobals->time + 1.0f;
		return;
	}

	Vector vecDir = m_hEnemy->v.origin - pev->origin;
	vecDir.z = 0;

	float flDist = vecDir.Length();
	if ( flDist < HUTAO_HEAVY_MIN_RANGE || flDist > HUTAO_HEAVY_MAX_RANGE )
	{
		m_flNextHeavyAttack = gpGlobals->time + 0.8f;
		return;
	}

	vecDir = vecDir.Normalize();
	StartHeavyAttack( vecDir );
}

void CMHutao :: StartHeavyAttack( const Vector &vecDir )
{
	m_fSprinting = FALSE;
	m_fHeavyAttacking = TRUE;
	m_flHeavyAttackUntil = gpGlobals->time + HUTAO_HEAVY_DURATION;
	m_flNextHeavyAttack = gpGlobals->time + HUTAO_HEAVY_INTERVAL;
	m_flNextDash = gpGlobals->time + 2.0f;
	m_flNextHeavyFlame = gpGlobals->time;
	m_iHeavyHitCount = 0;
	m_vecHeavyAttackDir = vecDir;
	m_vecHeavyLastOrigin = pev->origin;
	m_flStamina -= HUTAO_HEAVY_STAMINA_COST;
	if ( m_flStamina < 0 )
		m_flStamina = 0;

	pev->ideal_yaw = UTIL_VecToYaw( vecDir );
	ChangeYaw( pev->yaw_speed );
	pev->velocity = vecDir * HUTAO_HEAVY_SPEED;
	if ( pev->velocity.z < 70.0f )
		pev->velocity.z = 70.0f;
	pev->flags &= ~FL_ONGROUND;

	EMIT_SOUND_DYN( ENT( pev ), CHAN_VOICE, RANDOM_SOUND_ARRAY( pHutaoHeavyPainSounds ), 1.0, ATTN_NORM, 0, 100 + RANDOM_LONG( -5, 5 ) );
	m_flVoiceBusyUntil = gpGlobals->time + HUTAO_SHORT_VOICE_DURATION;
	m_flNextIdleSound = gpGlobals->time + RANDOM_FLOAT( 12.0f, 18.0f );
	SetActivity( ACT_MELEE_ATTACK2 );
	HutaoSpawnFlame( pev->origin, edict() );
}

void CMHutao :: UpdateHeavyAttack( void )
{
	if ( !m_fHeavyAttacking )
		return;

	if ( gpGlobals->time >= m_flHeavyAttackUntil || !IsAlive() )
	{
		m_fHeavyAttacking = FALSE;
		pev->velocity.x *= 0.35f;
		pev->velocity.y *= 0.35f;
		pev->framerate = 1.0f;
		return;
	}

	pev->ideal_yaw = UTIL_VecToYaw( m_vecHeavyAttackDir );
	ChangeYaw( pev->yaw_speed );
	pev->velocity.x = m_vecHeavyAttackDir.x * HUTAO_HEAVY_SPEED;
	pev->velocity.y = m_vecHeavyAttackDir.y * HUTAO_HEAVY_SPEED;
	SetActivity( ACT_RUN );

	Vector vecDelta = pev->origin - m_vecHeavyLastOrigin;
	float flDistance = vecDelta.Length2D();
	int steps = (int)( flDistance / 48.0f ) + 1;
	if ( steps < 1 )
		steps = 1;
	if ( steps > 8 )
		steps = 8;

	for ( int i = 0; i <= steps; i++ )
	{
		float fraction = (float)i / (float)steps;
		Vector vecPoint = m_vecHeavyLastOrigin + vecDelta * fraction;
		DamageHeavyAttackTargets( vecPoint );
	}

	if ( m_flNextHeavyFlame <= gpGlobals->time )
	{
		HutaoSpawnFlame( pev->origin, edict() );
		m_flNextHeavyFlame = gpGlobals->time + 0.12f;
	}

	m_vecHeavyLastOrigin = pev->origin;
}

void CMHutao :: ClearSkillStateOnDeath( void )
{
	m_fHeavyAttacking = FALSE;
	m_fSprinting = FALSE;
	m_flHeavyAttackUntil = 0;
	m_flSprintUntil = 0;
	m_iHeavyHitCount = 0;
	m_vecHeavyAttackDir = g_vecZero;
	m_vecHeavyLastOrigin = pev->origin;
	pev->framerate = 1.0f;
	pev->velocity.x = 0;
	pev->velocity.y = 0;
	if ( pev->velocity.z > 0 )
		pev->velocity.z = 0;
	pev->avelocity = g_vecZero;
}

void CMHutao :: DamageHeavyAttackTargets( const Vector &vecCenter )
{
	edict_t *targets[32];
	int count = UTIL_MonstersInSphere( targets, ARRAYSIZE( targets ), vecCenter, HUTAO_HEAVY_HIT_RADIUS );

	for ( int i = 0; i < count; i++ )
	{
		edict_t *pTarget = targets[i];
		BOOL alreadyHit = FALSE;

		for ( int hit = 0; hit < m_iHeavyHitCount; hit++ )
		{
			if ( m_hHeavyHitTargets[hit] == pTarget )
			{
				alreadyHit = TRUE;
				break;
			}
		}

		if ( alreadyHit || !HutaoCanDamageTarget( pTarget, edict() ) )
			continue;

		BOOL wasPlayer = UTIL_IsPlayer( pTarget );
		HutaoDamageTarget( pTarget, edict(), pev, gSkillData.hutaoDmgHeavy, DMG_SLASH | DMG_BURN | DMG_NEVERGIB );
		HutaoApplyBurn( pTarget, edict() );
		AddSP( HUTAO_SP_ON_HIT );

		Vector vecKnock = pTarget->v.origin - pev->origin;
		vecKnock.z = 0;
		if ( vecKnock.Length() > 0 )
			vecKnock = vecKnock.Normalize();
		else
			vecKnock = m_vecHeavyAttackDir;

		pTarget->v.velocity = pTarget->v.velocity + vecKnock * 260;
		pTarget->v.velocity.z += 120;

		if ( wasPlayer && !UTIL_IsAlive( pTarget ) )
			AddSP( HUTAO_SP_ON_PLAYER_KILL );

		if ( m_iHeavyHitCount < HUTAO_HEAVY_MAX_HITS )
			m_hHeavyHitTargets[m_iHeavyHitCount++] = pTarget;
	}
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
	ClearSkillStateOnDeath();
	BOOL shouldGib = ShouldGibMonster( iGib );

	if ( !HasMemory( bits_MEMORY_KILLED ) )
		DeathSound();

	CMBaseMonster::Killed( pevAttacker, iGib );

	if ( !shouldGib )
		m_flDeadCleanupTime = gpGlobals->time + HUTAO_DEATH_CLEANUP_DELAY;
	else
		m_flDeadCleanupTime = 0;
}

void CMHutao :: BecomeDead( void )
{
	ClearSkillStateOnDeath();
	CMBaseMonster::BecomeDead();
	pev->velocity.x = 0;
	pev->velocity.y = 0;
	pev->avelocity = g_vecZero;
}

void CMHutao :: RemoveDeadBody( void )
{
	m_flDeadCleanupTime = 0;
	ClearSkillStateOnDeath();
	StopAnimation();

	pev->deadflag = DEAD_DEAD;
	pev->takedamage = DAMAGE_NO;
	pev->solid = SOLID_NOT;
	pev->movetype = MOVETYPE_NONE;
	pev->velocity = g_vecZero;
	pev->avelocity = g_vecZero;
	pev->effects |= EF_NODRAW;
	UTIL_SetSize( pev, g_vecZero, g_vecZero );
	UTIL_SetOrigin( pev, pev->origin );

	SetTouch( NULL );
	SetThink( &CMBaseMonster::SUB_Remove );
	pev->nextthink = gpGlobals->time + 0.15f;
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
