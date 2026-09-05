
Function Write-xJobProgress
{
    param(
        [System.Management.Automation.Job[]]$Job
    )

    process
    {
        foreach ($j in $Job)
        {
            #Extracts the latest progress of the job and writes the progress
            $jobProgressHistory = $j.ChildJobs[0].Progress
            $latestProgress = $jobProgressHistory[$jobProgressHistory.Count - 1]
            $latestPercentComplete = $latestProgress.PercentComplete
            $latestActivity = $latestProgress.Activity
            $latestStatus = $latestProgress.StatusDescription

            #When adding multiple progress bars, a unique ID must be provided. Here I am providing the JobID as this
            Write-Progress -Id $j.Id -Activity $latestActivity -Status $latestStatus -PercentComplete $latestPercentComplete;
        }
    }
}