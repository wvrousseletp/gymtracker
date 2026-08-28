#!/bin/bash
SHA="e85cbcae7ba1bad5bfce270ec869cd899f59a90d"
echo "Monitoring $SHA..."
while true; do
  STATUS=$(gh run list -c $SHA -w "Deploy to TestFlight" --json status -q '.[0].status')
  if [ "$STATUS" = "completed" ]; then
    CONCLUSION=$(gh run list -c $SHA -w "Deploy to TestFlight" --json conclusion -q '.[0].conclusion')
    echo "Workflow Deploy to TestFlight completed with conclusion: $CONCLUSION"
    break
  fi
  sleep 60
done
