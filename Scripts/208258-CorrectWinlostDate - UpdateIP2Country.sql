/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

-- correct winlostdate
UPDATE dbo.Task_bettrans14_IP2Country WITH(ROWLOCK, UPDLOCK)
	SET Winlostdate = '2024-07-16'
WHERE transid IN(277244537007505431,277249364550746116) 

GO
