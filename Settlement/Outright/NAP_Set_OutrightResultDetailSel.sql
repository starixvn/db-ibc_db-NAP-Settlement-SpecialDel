/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_OutrightResultDetailSel]
(
	 @OridList INT   
)
AS 
/*
    Created by: 20250814@Hughie
    Task: Get info of outright confirm
    DB: DBPRO/BODB02 
    
    Revisions:
		-20250109@Hughie: Apply SOP for Outright [Readmine:#232955]

	Param's Explanation:
*/

BEGIN

	DECLARE @tmpOrid TABLE (Orid SMALLINT)
	INSERT INTO @tmpOrid(Orid)
	SELECT f.value
	FROM STRING_SPLIT(@OridList,',') f

	SELECT r.Orid, r.Teamid, r.leagueid, r.Result, t.username
	FROM ResultDetailOutright r WITH (NOLOCK)
		INNER JOIN @tmpOrid f ON f.Orid = r.Orid
		CROSS APPLY (SELECT TOP 1 username AS username
					 FROM DBCUST.CustDB.dbo.custInfo c WITH(NOLOCK) 
					 WHERE c.custid = r.ModifiedBy
					 ORDER BY r.ModifiedDate DESC
		) t
END
