/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_06]
/*
	Created by: 20201006@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20240626@Kathy: update winlostdate

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep
*/	
AS
BEGIN
	SET NOCOUNT ON

	IF @@SERVERNAME <> 'DBTRANS'
		RETURN
	DECLARE @tmpTransId TABLE (TransId BIGINT)
	
	BEGIN
		INSERT INTO @tmpTransId (TransId)
		SELECT transid 
		FROM dbo.bettrans14 WITH (NOLOCK) 
		WHERE transid in (268328047466250273, 268328940819447859, 268331977361326153)
		
		INSERT INTO dbo.bettrans14 
			   ([transid]
			   ,[custid]
			   ,[transdate]
			   ,[oddsid]
			   ,[hdp1]
			   ,[hdp2]
			   ,[odds]
			   ,[stake]
			   ,[status]
			   ,[winlost]
			   ,[awinlost]
			   ,[mwinlost]
			   ,[playercomm]
			   ,[comm]
			   ,[acomm]
			   ,[apositiontaking]
			   ,[mpositiontaking]
			   ,[tpositiontaking]
			   ,[playerdiscount]
			   ,[discount]
			   ,[adiscount]
			   ,[livehomescore]
			   ,[liveawayscore]
			   ,[liveindicator]
			   ,[betteam]
			   ,[creator]
			   ,[refno]
			   ,[comstatus]
			   ,[winlostdate]
			   ,[betfrom]
			   ,[betcheck]
			   ,[checktime]
			   ,[oddsspread]
			   ,[actualrate]
			   ,[matchid]
			   ,[recommend]
			   ,[mrecommend]
			   ,[ruben]
			   ,[betid]
			   ,[statuswinlost]
			   ,[modds]
			   ,[bettype]
			   ,[betdaqid]
			   ,[tstamp]
			   ,[actual_stake]
			   ,[currency]
			   ,[ip]
			   ,[transdesc]
			   ,[sdiscount]
			   ,[scomm]
			   ,[spositiontaking]
			   ,[swinlost]
			   ,[srecommend]
			   ,[virtualrate]
			   ,[Username]
			   ,[CurrencyName]
			   ,[oddstype]
			   ,[statusID]
			   ,[currency2]
			   ,[balance]
			   ,[SecAcceptFlag]
			   ,[transid2]
			   ,[recommdate]
			   ,[ExtraInfo]
			   ,[WalletType]
			   ,[BonusID]
			   ,[RefCode]
			   ,[SettlementTime]
			   ,[epositiontaking]
			   ,[ReasonID]
			   ,[sort]
			   ,[SiteDBGroupID]
			   ,[DeviceType]
			  )
		SELECT [transid]
			   ,[custid]
			   ,[transdate]
			   ,[oddsid]
			   ,[hdp1]
			   ,[hdp2]
			   ,[odds]
			   ,[stake]
			   ,[status]
			   ,[winlost]
			   ,[awinlost]
			   ,[mwinlost]
			   ,[playercomm]
			   ,[comm]
			   ,[acomm]
			   ,[apositiontaking]
			   ,[mpositiontaking]
			   ,[tpositiontaking]
			   ,[playerdiscount]
			   ,[discount]
			   ,[adiscount]
			   ,[livehomescore]
			   ,[liveawayscore]
			   ,[liveindicator]
			   ,[betteam]
			   ,[creator]
			   ,[refno]
			   ,[comstatus]
			   ,[winlostdate]
			   ,[betfrom]
			   ,[betcheck]
			   ,[checktime]
			   ,[oddsspread]
			   ,[actualrate]
			   ,[matchid]
			   ,[recommend]
			   ,[mrecommend]
			   ,[ruben]
			   ,[betid]
			   ,[statuswinlost]
			   ,[modds]
			   ,[bettype]
			   ,[betdaqid]
			   ,[tstamp]
			   ,[actual_stake]
			   ,[currency]
			   ,[ip]
			   ,[transdesc]
			   ,[sdiscount]
			   ,[scomm]
			   ,[spositiontaking]
			   ,[swinlost]
			   ,[srecommend]
			   ,[virtualrate]
			   ,[Username]
			   ,[CurrencyName]
			   ,[oddstype]
			   ,[statusID]
			   ,[currency2]
			   ,[balance]
			   ,[SecAcceptFlag]
			   ,[transid2]
			   ,[recommdate]
			   ,[ExtraInfo]
			   ,[WalletType]
			   ,[BonusID]
			   ,[RefCode]
			   ,[SettlementTime]
			   ,[epositiontaking]
			   ,[ReasonID]
			   ,[sort]
			   ,[SiteDBGroupID]
			   ,[DeviceType]
		FROM	DBACC.bodb02.dbo.bettrans14 WITH(NOLOCK)
		WHERE	transid in (268328047466250273, 268328940819447859, 268331977361326153)
				AND transid not in (SELECT transid FROM @tmpTransId)
		
		DELETE @tmpTransId
		
		INSERT INTO @tmpTransId(TransId)
		SELECT 	transid
		FROM 	dbo.bettrans WITH(NOLOCK)
		WHERE	transid in (268328047466250273, 268328940819447859, 268331977361326153)
		
		DELETE 
		FROM dbo.bettrans WITH(ROWLOCK, UPDLOCK)
		WHERE	transid in (SELECT transid FROM @tmpTransId)
	END
END

GO 
USE bodb02
GO
EXEC dbo.ExecRep_NAP_Admin_06
GO 

UPDATE	org WITH(ROWLOCK, UPDLOCK)
	SET	winlost = t.Winlost
		,AWinlost = t.AWinlost
		,MWinlost = t.MWinlost
		,SWinlost = t.SWinlost
		,PlayerComm = t.PlayerComm
		,Comm = t.Comm
		,AComm = t.AComm
		,SComm = t.SComm
		,Stake = t.Stake
		,Actual_Stake = t.Actual_Stake
FROM	dbo.Transfer org
	INNER JOIN BKtableDB.dbo.__transfer__#20240622 t WITH(NOLOCK)
		ON org.transid = t.transid
GO