/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_SDT_OS_modds] (
		 @pfID			SMALLINT
		,@betteam 		NVARCHAR(10)
		,@hdp1			SMALLMONEY
		,@hdp2			SMALLMONEY
		,@HomeValue		VARCHAR(2000)
		,@AwayValue		VARCHAR(2000)		
		,@Transdesc		NVARCHAR(1000)
		,@MinusValue	SMALLMONEY
		,@AbandonedStatus	SMALLINT
		)
RETURNS TABLE
AS  
/*	Created: 20230510@Aries
	Task: SDT - cal modds
	DB: DBTXN/bodb02
	Revisions:	
		- 20230510@Aries: Apply Settle Determined for Basketball [Redmine:#184124]
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
		- 20241111@Louisa: Refund SDT Baseball (Mercyrule) - [Redmine:#212365]
	Param's Explanation:
		- @MinusValue: Basketball instance
		- @AbandonedStatus: 0: normal case (early completed)
						    1: Away not yet completed
*/
RETURN
(
	SELECT  CASE 
			WHEN @pfID IN (3,401, 402) THEN --Over/under
				CASE WHEN @betteam IN ('h', 'o') AND tbl.fm > 0.25 THEN 1
					 WHEN @betteam IN ('a', 'u') AND tbl.fm > 0.25 THEN -1
					 ELSE NULL END		
			WHEN @pfID IN (8809) THEN --Over/under
				CASE WHEN @AbandonedStatus IN (0,1) AND  @betteam IN ('h', 'o') AND tbl.fm > 0.25 THEN 1
					 WHEN @AbandonedStatus IN (0,1) AND  @betteam IN ('a', 'u') AND tbl.fm > 0.25 THEN -1

					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('h', 'o') AND tbl.fm = 0.25	THEN 0.25
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('h', 'o') AND tbl.fm = 0		THEN 0
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('h', 'o') AND tbl.fm = -0.25	THEN -0.25
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('h', 'o') AND tbl.fm < -0.25	THEN -1

					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('a', 'u') AND tbl.fm = 0.25	THEN -0.25
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('a', 'u') AND tbl.fm = 0		THEN 0
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('a', 'u') AND tbl.fm = -0.25	THEN 0.25
					 WHEN @AbandonedStatus = 0 AND  @betteam IN ('a', 'u') AND tbl.fm < -0.25	THEN 1
		
					 ELSE NULL END	
			WHEN @pfID = 100 THEN --betteam = homevalue (home/away/none/draw)
			   CASE WHEN @betteam IN ('h', 'a') AND @betteam = @HomeValue THEN 1
					WHEN @HomeValue IN ('n') THEN 0
					WHEN ISNULL(@HomeValue,'') = '' THEN NULL
					ELSE -1 END
			WHEN @pfID = 633 THEN
				CASE  WHEN @betteam NOT LIKE @HomeValue	THEN -1
					  WHEN @betteam = @HomeValue THEN 1
					  ELSE NULL END 		
			WHEN @pfID = 635 THEN
				CASE WHEN @betteam = 'h' AND CAST(@AwayValue AS INT) > 4 THEN -1
					 WHEN @betteam = 'a' AND CAST(@HomeValue AS INT) > 4 THEN -1 
					 WHEN CAST(@HomeValue AS INT) = 4 AND CAST(@AwayValue AS INT) = 4 THEN -1 
					 WHEN @betteam = 'h' AND (CAST(@HomeValue AS INT) > 4 AND CAST(@AwayValue AS INT) = 4) THEN 1
					 WHEN @betteam = 'a' AND (CAST(@HomeValue AS INT) = 4 AND CAST(@AwayValue AS INT) > 4) THEN 1 
					 ELSE NULL END
			WHEN @pfID = 638 THEN
				CASE WHEN @betteam IN ('h', 'o') AND tbl.fm > 0 THEN 1
					 WHEN @betteam IN ('a', 'u') AND tbl.fm > 0 THEN -1   
					 WHEN @betteam IN ('h', 'o') AND tbl.fm < 0 AND @hdp1 - (4 - CAST(@AwayValue AS SMALLMONEY) + CAST(@HomeValue AS SMALLMONEY)) >= 0 THEN -1
					 WHEN @betteam IN ('a', 'u') AND tbl.fm < 0 AND @hdp1 - (4 - CAST(@AwayValue AS SMALLMONEY) + CAST(@HomeValue AS SMALLMONEY)) >= 0 THEN 1
					 WHEN @betteam IN ('h', 'o') AND tbl.fm = 0 AND @hdp1 - (4 - CAST(@AwayValue AS SMALLMONEY) + CAST(@HomeValue AS SMALLMONEY)) >= 0 THEN 0
					 WHEN @betteam IN ('a', 'u') AND tbl.fm = 0 AND @hdp1 - (4 - CAST(@AwayValue AS SMALLMONEY) + CAST(@HomeValue AS SMALLMONEY)) >= 0 THEN 0
					 ELSE NULL END	
			WHEN @pfID = 640 THEN
				CASE WHEN @betteam = '0' AND CAST(@HomeValue AS INT) > 4 THEN -1
					 WHEN @betteam = '0' AND CAST(@HomeValue AS INT) = 4 THEN 1
					 WHEN @betteam = '1' AND CAST(@HomeValue AS INT) > 4 THEN 1
					 WHEN @betteam = '1' AND CAST(@HomeValue AS INT) = 4 THEN -1
					ELSE NULL END
			WHEN @pfID = 642 THEN
				CASE WHEN CHARINDEX('q1h', @HomeValue) > 0 AND @betteam LIKE 'a1[1-4]'  THEN -1
					 WHEN CHARINDEX('q2h', @HomeValue) > 0 AND (@betteam LIKE 'a2[1-4]' OR @betteam LIKE 'a[1-4]2') THEN -1
					 WHEN CHARINDEX('q3h', @HomeValue) > 0 AND (@betteam LIKE 'a3[1-4]' OR @betteam LIKE 'a[1-4]3') THEN -1
					 WHEN CHARINDEX('q4h', @HomeValue) > 0 AND (@betteam LIKE 'a4[1-4]' OR @betteam LIKE 'a[1-4]4') THEN -1

					 WHEN CHARINDEX('q1a', @HomeValue) > 0 AND @betteam LIKE 'h1[1-4]'  THEN -1
					 WHEN CHARINDEX('q2a', @HomeValue) > 0 AND (@betteam LIKE 'h2[1-4]' OR @betteam LIKE 'h[1-4]2') THEN -1
					 WHEN CHARINDEX('q3a', @HomeValue) > 0 AND (@betteam LIKE 'h3[1-4]' OR @betteam LIKE 'h[1-4]3') THEN -1
					 WHEN CHARINDEX('q4a', @HomeValue) > 0 AND (@betteam LIKE 'h4[1-4]' OR @betteam LIKE 'h[1-4]4') THEN -1

					 WHEN CHARINDEX('q1d', @HomeValue) > 0 AND @betteam LIKE 'aos1[1-4]'  THEN 1
					 WHEN CHARINDEX('q1d', @HomeValue) > 0 AND (@betteam LIKE 'a1[1-4]'	  OR @betteam LIKE 'h1[1-4]')	THEN -1

					 WHEN CHARINDEX('q2d', @HomeValue) > 0 AND (@betteam LIKE 'aos2[1-4]' OR @betteam LIKE 'aos[1-4]2') THEN 1
					 WHEN CHARINDEX('q2d', @HomeValue) > 0 AND (@betteam LIKE 'a2[1-4]'   OR @betteam LIKE 'a[1-4]2' OR @betteam LIKE 'h2[1-4]'   OR @betteam LIKE 'h[1-4]2') THEN -1

					 WHEN CHARINDEX('q3d', @HomeValue) > 0 AND (@betteam LIKE 'aos3[1-4]' OR @betteam LIKE 'aos[1-4]3') THEN 1
					 WHEN CHARINDEX('q3d', @HomeValue) > 0 AND (@betteam LIKE 'a3[1-4]'   OR @betteam LIKE 'a[1-4]3' OR @betteam LIKE 'h3[1-4]'   OR @betteam LIKE 'h[1-4]3') THEN -1

					 WHEN CHARINDEX('q4d', @HomeValue) > 0 AND (@betteam LIKE 'aos4[1-4]' OR @betteam LIKE 'aos[1-4]4') THEN 1
					 WHEN CHARINDEX('q4d', @HomeValue) > 0 AND (@betteam LIKE 'a4[1-4]'   OR @betteam LIKE 'a[1-4]4' OR @betteam LIKE 'h4[1-4]'   OR @betteam LIKE 'h[1-4]4') THEN -1
	
					 WHEN @betteam =  'aos12'  AND (@HomeValue LIKE '%h12%' OR @HomeValue LIKE '%a12%' ) THEN -1
					 WHEN @betteam =  'aos13'  AND (@HomeValue LIKE '%h13%' OR @HomeValue LIKE '%a13%' ) THEN -1
					 WHEN @betteam =  'aos14'  AND (@HomeValue LIKE '%h14%' OR @HomeValue LIKE '%a14%' ) THEN -1
					 WHEN @betteam =  'aos23'  AND (@HomeValue LIKE '%h23%' OR @HomeValue LIKE '%a23%' ) THEN -1
					 WHEN @betteam =  'aos24'  AND (@HomeValue LIKE '%h24%' OR @HomeValue LIKE '%a24%' ) THEN -1
					 WHEN @betteam =  'aos34'  AND (@HomeValue LIKE '%h34%' OR @HomeValue LIKE '%a34%' ) THEN -1

					 WHEN CHARINDEX(@betteam, @HomeValue) > 0 THEN 1
						
					 ELSE NULL END
			WHEN @pfID = 643 THEN
				CASE WHEN @AwayValue NOT LIKE '%Current('+ @betteam +')%' AND @AwayValue LIKE '%tie('+ @betteam +')%'  THEN -1
					 WHEN @AwayValue NOT LIKE '%Current('+ @betteam +')%' AND @AwayValue LIKE '%Low('+ @betteam +')%'  THEN -1
			         WHEN @HomeValue != @betteam AND @AwayValue LIKE '%1q,2q,3q,4q%' AND (@AwayValue NOT LIKE '%Current%' OR @AwayValue LIKE '%Current('+ @HomeValue +')%')  THEN -1
			         WHEN CHARINDEX(@betteam, @HomeValue) > 0  AND @AwayValue LIKE '%1q,2q,3q,4q%' AND (@AwayValue NOT LIKE '%Current%' OR  @AwayValue LIKE '%Current('+ @betteam +')%')  THEN 1
                     ELSE NULL END
			WHEN @pfID = 646 THEN
				CASE WHEN @betteam IN ('HU', 'AU') AND tbl.fm > 0 THEN -1
					 ELSE NULL END	
			WHEN @pfID IN( 8826) THEN
				CASE WHEN @betteam = '1-2' AND fm BETWEEN 3 AND 4 THEN -1
					 WHEN @betteam IN ('1-2','3-4') AND fm BETWEEN 5 AND 6 THEN -1
					 WHEN @betteam IN ('1-2','3-4','5-6') AND fm BETWEEN 7 AND 8 THEN -1
					 WHEN @betteam IN ('1-2','3-4','5-6','7-8') AND fm BETWEEN 9 AND 10 THEN -1
					 WHEN @betteam IN ('1-2','3-4','5-6','7-8','9-10') AND fm BETWEEN 11 AND 12 THEN -1
					 WHEN @betteam IN ('1-2','3-4','5-6','7-8','9-10','11-12') AND fm BETWEEN 13 AND 14 THEN -1
					 WHEN @betteam IN ('1-2','3-4','5-6','7-8','9-10','11-12','13-14') AND fm >= 15 THEN -1
					 WHEN @betteam = '15+' AND fm >= 15 THEN 1			 
					 ELSE NULL END
			WHEN @pfID = 8825 THEN
				CASE WHEN @betteam IN ('hu', 'au') AND (CAST(@HomeValue AS INT) + CAST(@AwayValue AS INT) - @hdp1) > 0 THEN -1
					 ELSE NULL END	
			WHEN @pfID = 8814 THEN
				CASE WHEN (CAST(@HomeValue AS INT) - (CAST(@hdp1 AS INT)%800) >= 0) AND (CAST(@AwayValue AS INT) - (CAST(@hdp1 AS INT)%800) >= 0) THEN CASE WHEN @betteam = 'y' THEN 1 ELSE -1 END
					 WHEN @AbandonedStatus = 1 AND (CAST(@AwayValue AS INT) - (CAST(@hdp1 AS INT)%800) < 0) THEN 
																											CASE WHEN @betteam = 'y' THEN -1 
																											ELSE 1 END
					 ELSE NULL END	
			WHEN @pfID = 20 THEN 
				CASE WHEN @AbandonedStatus = 1 THEN NULL
					WHEN @AbandonedStatus = 0 AND @betteam = 'h' AND fm > 0 THEN 1
					WHEN @AbandonedStatus = 0 AND @betteam = 'a' AND fm > 0 THEN -1
					ELSE NULL END
			WHEN @pfid = 8813 THEN
				CASE
					WHEN @betteam = '3+' AND fm >= 3 THEN 1 
					ELSE NULL END
			WHEN @pfID = 8805 THEN
				CASE WHEN @AbandonedStatus = 1 THEN NULL
					 WHEN @AbandonedStatus = 0 AND fm > 0 AND @betteam IN ('h')		THEN 1
					 WHEN @AbandonedStatus = 0 AND fm > 0 AND @betteam IN ('d', 'a') THEN -1
					 WHEN @AbandonedStatus = 0 AND fm = 0 AND @betteam  IN ('a')		THEN -1
					ELSE NULL END
			WHEN @pfID = 424 THEN
				CASE WHEN @betteam = 'h' AND @HomeValue = 'h' THEN 1
					 WHEN @betteam = 'a' AND @HomeValue IN ( 'h','d') THEN -1
					 WHEN @betteam = 'd' AND @HomeValue = 'h' THEN -1
					ELSE NULL END
			WHEN @pfID = 10 THEN
				CASE WHEN @AbandonedStatus = 1 THEN NULL
					 WHEN @betteam = 'h' AND fm > 0.5 THEN 1
					 WHEN @betteam = 'a' AND fm > 0.5 THEN -1
					 ELSE NULL END

			ELSE NULL
		END AS modds
	FROM(
		SELECT (CASE WHEN @pfID IN (3,646, 83) THEN (CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY) - @MinusValue - @hdp1)	
					 WHEN @pfID = 10 THEN (CAST(@HomeValue AS SMALLMONEY) - @hdp1) - (CAST(@AwayValue AS SMALLMONEY) - @hdp2)
					 WHEN @pfID IN (20,8805) THEN CAST(@HomeValue AS MONEY) - CAST(@AwayValue AS MONEY)			
					 WHEN @pfID IN (401,638) THEN CAST(@HomeValue AS SMALLMONEY) - @hdp1 - @MinusValue
					 WHEN @pfID IN (402,8809) THEN CAST(@AwayValue AS SMALLMONEY) - @hdp1 - @MinusValue
					 WHEN @pfID IN (8826,8813) THEN CAST(@HomeValue AS SMALLMONEY) + CAST(@AwayValue AS SMALLMONEY)
					 ELSE -1 END
		) AS fm
	) tbl
	GROUP BY tbl.fm

)
GO
