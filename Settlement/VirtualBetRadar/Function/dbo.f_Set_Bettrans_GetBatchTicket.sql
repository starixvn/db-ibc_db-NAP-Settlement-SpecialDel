/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_Bettrans_GetBatchTicket] (
	@matchid 			INT
	, @bettypes			VARCHAR(MAX)
	, @batchcount		INT
)
RETURNS TABLE
AS

/*
    Created: 20160606@Bobby
	Task :  77720 - Implement VS BetRadar League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		
    Columns Explanation:    
		- @modds: SMALLMONEY modds value for calculating won/lose of bet ticket
    
*/
RETURN (
	WITH tempBettype AS (
		SELECT temp.bettype
		FROM 
		(
			SELECT CONVERT(XML, @bettypes) AS Bettypes
		) AS xdocs
		OUTER APPLY (
		
			SELECT T.C.value('./@t', 'SMALLINT') AS bettype
			FROM xdocs.Bettypes.nodes('/root/r') AS T(C)
		) AS temp
	) 
	SELECT batchNo
		, MIN(transid) AS fromTransId
		, MAX(transid) AS toTransId
	FROM (
		SELECT transid
			, batchNo = (
				ROW_NUMBER() OVER (
					ORDER BY rn
					) + 1
				) / 2
		FROM (
			SELECT transid
				, rn = ROW_NUMBER() OVER (
					ORDER BY transid
					)
				, rn_rev = ROW_NUMBER() OVER (
					ORDER BY transid DESC
					)
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN tempBettype AS temp
				ON b.bettype = temp.bettype
				
			WHERE matchid = @matchid
				AND b.statusID NOT IN (101,102) --void/reject
		) x
		WHERE rn % @batchcount = 0 -- toTransId
			OR (rn - 1) % @batchcount = 0 -- fromTransId
			OR rn_rev = 1 --maxTransId
	) AS t
	GROUP BY batchNo
)
GO
