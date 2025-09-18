/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250918@Max
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	Task: Fix the issue where the daily KPI report for Soccer sent incorrect data on Sep 17 [Redmine: #239282]

*/

USE bodb02
GO

DECLARE @MinSingleKeyId BIGINT
	,@MinParlayKeyId BIGINT

SELECT @MinSingleKeyId = MAX(KeyId) FROM dbo.Single_Calculate_Queue WITH (NOLOCK) WHERE CAST(starttime AS DATE) = '2025-09-16'
SELECT @MinParlayKeyId = MAX(KeyId) FROM dbo.Parlay_Calculate_Queue WITH (NOLOCK) WHERE CAST(starttime AS DATE) = '2025-09-16'

UPDATE	s SET VValue = @MinSingleKeyId
		FROM	dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
		WHERE	VName = 'Single_Calculate_Queue'
															   
UPDATE	s SET VValue = @MinParlayKeyId
		FROM	dbo.SystemSettings s WITH(ROWLOCK, UPDLOCK)
		WHERE	VName = 'Parlay_Calculate_Queue'
		