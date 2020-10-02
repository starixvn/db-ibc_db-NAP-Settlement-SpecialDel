/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CustomerSelInfoByUsername]
	@UserName	VARCHAR(30)
AS
/*
Created: 20140911@Jamie
Task : Get CustID, RoleID, Currency by Username FOR all system 
DB: DBACC/BODB02
Original: Acc_CustomerSelInfoByUsername

Revisions:
	
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	SELECT	 tmp.CustID
			,tmp.Roleid
			,tmp.Currency
	FROM [dbo].[custInfo] sma WITH (NOLOCK)
	CROSS APPLY ( SELECT down.CustID
						,down.Roleid
						,down.Currency
					FROM [dbo].[custInfo] down WITH (NOLOCK)
					WHERE 1 = CASE WHEN sma.custid = down.custid AND sma.custid NOT IN (down.recommend,down.mrecommend,down.srecommend )THEN 1 -- lấy chính nó
								   WHEN ( sma.custid = down.recommend 
										OR sma.custid = down.mrecommend 
										OR sma.custid = down.srecommend
										) AND down.UserName <> @UserName -- ko lấy chính nó
									THEN 1 
									ELSE 0 END
				) as tmp
	WHERE sma.UserName = @UserName
END
GO