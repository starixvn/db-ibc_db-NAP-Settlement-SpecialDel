--Group 2 - In UM - fix data
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: fix data on sitedb03 [Redmineid:#181595] 

		1) Bettransm    
		2) zzzbettrans  
		3) zzzbettransm 

*/
----------correct tickets---------------------------------
/* find text and replace by list of wrong recommends for table need to fix data
1) Bettransm    -> bettransm_TransidList
2) zzzbettrans  -> zzzbettrans_KeyIDList
3) zzzbettransm -> zzzbettransm_KeyIDList

*/
BEGIN--------1) Bettransm  --------------------------------------

	SELECT * 
	INTO #temp_Bettransm
	FROM DBCTG.bodb02.dbo.Bettransm  WITH (NOLOCK)
	WHERE transid IN (bettransm_TransidList)

	UPDATE b 
		SET
			[custid]	=	g.[custid],
			[transdate]	=	g.[transdate],
			[oddsid]	=	g.[oddsid],
			[hdp1]	=	g.[hdp1],
			[hdp2]	=	g.[hdp2],
			[odds]	=	g.[odds],
			[stake]	=	g.[stake],
			[status]	=	g.[status],
			[winlost]	=	g.[winlost],
			[livehomescore]	=	g.[livehomescore],
			[liveawayscore]	=	g.[liveawayscore],
			[liveindicator]	=	g.[liveindicator],
			[betteam]	=	g.[betteam],
			[creator]	=	g.[creator],
			[refno]	=	g.[refno],
			[comstatus]	=	g.[comstatus],
			[winlostdate]	=	g.[winlostdate],
			[betfrom]	=	g.[betfrom],
			[betcheck]	=	g.[betcheck],
			[checktime]	=	g.[checktime],
			[oddsspread]	=	g.[oddsspread],
			[apositiontaking]	=	g.[apositiontaking],
			[mpositiontaking]	=	g.[mpositiontaking],
			[tpositiontaking]	=	g.[tpositiontaking],
			[awinlost]	=	g.[awinlost],
			[mwinlost]	=	g.[mwinlost],
			[playerdiscount]	=	g.[playerdiscount],
			[discount]	=	g.[discount],
			[adiscount]	=	g.[adiscount],
			[playercomm]	=	g.[playercomm],
			[comm]	=	g.[comm],
			[acomm]	=	g.[acomm],
			[actualrate]	=	g.[actualrate],
			[matchid]	=	g.[matchid],
			[matchdate]	=	g.[matchdate],
			[finalodds]	=	g.[finalodds],
			[isfinish]	=	g.[isfinish],
			[statuswinlost]	=	g.[statuswinlost],
			[ruben]	=	g.[ruben],
			[bettype]	=	g.[bettype],
			[spositiontaking]	=	g.[spositiontaking],
			[swinlost]	=	g.[swinlost],
			[sdiscount]	=	g.[sdiscount],
			[scomm]	=	g.[scomm],
			[statusID]	=	g.[statusID],
			[recommdate]	=	g.[recommdate],
			[transdesc]	=	g.[transdesc],
			[SecAcceptFlag]	=	g.[SecAcceptFlag],
			[SecAcceptTime]	=	g.[SecAcceptTime],
			[LiveBetAcceptTime]	=	g.[LiveBetAcceptTime],
			[ReasonIDm]	=	g.[ReasonIDm]

	FROM Bettransm b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_Bettransm g WITH (NOLOCK) ON b.transid  = g.transid
	WHERE b.transid IN (bettransm_TransidList)

END
BEGIN--------2) zzzbettrans  --------------------------------------

	SELECT * 
	INTO #temp_zzzbettrans
	FROM DBCTG.bodb02.dbo.zzzbettrans  WITH (NOLOCK)
	WHERE keyid IN (zzzbettrans_KeyIDList)

	UPDATE b	
		SET 
		[transid]	=	g.[transid],	
		[custid]	=	g.[custid],	
		[transdate]	=	g.[transdate],	
		[oddsid]	=	g.[oddsid],	
		[hdp1]	=	g.[hdp1],	
		[hdp2]	=	g.[hdp2],	
		[odds]	=	g.[odds],	
		[stake]	=	g.[stake],	
		[status]	=	g.[status],	
		[winlost]	=	g.[winlost],	
		[livehomescore]	=	g.[livehomescore],	
		[liveawayscore]	=	g.[liveawayscore],	
		[liveindicator]	=	g.[liveindicator],	
		[betteam]	=	g.[betteam],	
		[creator]	=	g.[creator],	
		[refno]	=	g.[refno],	
		[comstatus]	=	g.[comstatus],	
		[winlostdate]	=	g.[winlostdate],	
		[betfrom]	=	g.[betfrom],	
		[betcheck]	=	g.[betcheck],	
		[checktime]	=	g.[checktime],	
		[matchid]	=	g.[matchid],	
		[bettype]	=	g.[bettype],	
		[VoidingHistoryId]	=	g.[VoidingHistoryId]	

	FROM zzzbettrans b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_zzzbettrans g WITH (NOLOCK) ON b.keyid  = g.keyid
	WHERE b.keyid IN (zzzbettrans_KeyIDList)

END
BEGIN--------3) zzzbettransm  --------------------------------------
	
	SELECT * 
	INTO #temp_zzzbettransm
	FROM DBCTG.bodb02.dbo.zzzbettransm  WITH (NOLOCK)
	WHERE keyid IN (zzzbettransm_KeyIDList)

	UPDATE b 
		SET
		[transid]	=	g.[transid],
		[custid]	=	g.[custid],
		[transdate]	=	g.[transdate],
		[oddsid]	=	g.[oddsid],
		[hdp1]	=	g.[hdp1],
		[hdp2]	=	g.[hdp2],
		[odds]	=	g.[odds],
		[stake]	=	g.[stake],
		[status]	=	g.[status],
		[winlost]	=	g.[winlost],
		[livehomescore]	=	g.[livehomescore],
		[liveawayscore]	=	g.[liveawayscore],
		[liveindicator]	=	g.[liveindicator],
		[betteam]	=	g.[betteam],
		[creator]	=	g.[creator],
		[refno]	=	g.[refno],
		[comstatus]	=	g.[comstatus],
		[winlostdate]	=	g.[winlostdate],
		[betfrom]	=	g.[betfrom],
		[betcheck]	=	g.[betcheck],
		[checktime]	=	g.[checktime],
		[matchid]	=	g.[matchid],
		[bettype]	=	g.[bettype],
		[VoidingHistoryId]	=	g.[VoidingHistoryId]	

	FROM zzzbettransm b WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #temp_zzzbettransm g WITH (NOLOCK) ON b.keyid  = g.keyid
	WHERE b.keyid IN (zzzbettransm_KeyIDList)
END
