class AdAttribution::SendCapiEventJob < ApplicationJob
  queue_as :low

  def perform(conversion)
    AdAttribution::CapiEventService.new(conversion: conversion).perform
  end
end
