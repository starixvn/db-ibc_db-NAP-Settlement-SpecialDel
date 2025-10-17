/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
/*
    Created: 20251017@Hughie
	Task: Revoke Wrong Permission [Redmine: #233012]
	DB: DBPRO/bodb02
*/


USE bodb02
GO

REVOKE EXECUTE ON [dbo].[NAP_Set_ProviderExternalResultDetailIns] FROM [oneback_admin_smp_service];
GO